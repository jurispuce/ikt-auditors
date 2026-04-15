"""
One-shot loader for the MedReg audit-log demo.

Reads /data/medreg_audit_logs.json (mounted from ../input-docs/) and:
  1. Inserts every event into Postgres (audit.events), idempotent via
     ON CONFLICT (event_id) DO NOTHING.
  2. Pushes every event to Loki at http://loki:3100/loki/api/v1/push
     with stream labels {source_system, source_type, result} and the
     log line set to a compact JSON of the full record.

Container exits 0 on success; non-zero on hard failure.
"""

from __future__ import annotations

import json
import os
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

import psycopg
import requests
from tenacity import retry, stop_after_delay, wait_fixed

# ---- config from env --------------------------------------------------------

PG_DSN = (
    f"host={os.environ.get('PG_HOST', 'postgres')} "
    f"port={os.environ.get('PG_PORT', '5432')} "
    f"dbname={os.environ.get('PG_DB', 'medreg')} "
    f"user={os.environ.get('PG_USER', 'medreg')} "
    f"password={os.environ.get('PG_PASSWORD', 'medreg')}"
)
LOKI_URL = os.environ.get("LOKI_URL", "http://loki:3100")
DATA_FILE = Path(os.environ.get("DATA_FILE", "/data/medreg_audit_logs.json"))


# ---- wait for dependencies --------------------------------------------------

@retry(wait=wait_fixed(2), stop=stop_after_delay(120), reraise=True)
def wait_for_postgres() -> None:
    with psycopg.connect(PG_DSN, connect_timeout=3) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT 1")
            cur.fetchone()
    print("[loader] postgres ready")


@retry(wait=wait_fixed(2), stop=stop_after_delay(120), reraise=True)
def wait_for_loki() -> None:
    r = requests.get(f"{LOKI_URL}/ready", timeout=3)
    r.raise_for_status()
    if "ready" not in r.text.lower():
        raise RuntimeError(f"loki not ready: {r.text!r}")
    print("[loader] loki ready")


# ---- postgres ---------------------------------------------------------------

INSERT_SQL = """
INSERT INTO audit.events
    (event_id, timestamp_utc, timestamp_raw, timezone,
     source_system, source_type, user_id, user_ip,
     action, resource, result, details,
     hour_utc, dow_utc)
VALUES
    (%s, %s, %s, %s,
     %s, %s, %s, %s,
     %s, %s, %s, %s,
     %s, %s)
ON CONFLICT (event_id) DO NOTHING
"""


def _parse_utc(ts: str) -> datetime:
    return datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone(timezone.utc)


def fill_postgres(records: list[dict]) -> int:
    rows = []
    for r in records:
        dt = _parse_utc(r["timestamp_utc"])
        rows.append((
            r["event_id"],
            r["timestamp_utc"],
            r["timestamp_raw"],
            r["timezone"],
            r["source_system"],
            r["source_type"],
            r["user_id"],
            r.get("user_ip"),
            r["action"],
            r.get("resource"),
            r["result"],
            json.dumps(r.get("details", {})),
            dt.hour,
            dt.isoweekday(),  # 1=Mon ... 7=Sun, matches ISODOW
        ))
    with psycopg.connect(PG_DSN) as conn:
        with conn.cursor() as cur:
            cur.executemany(INSERT_SQL, rows)
            conn.commit()
            cur.execute("SELECT count(*) FROM audit.events")
            (total,) = cur.fetchone()
    print(f"[loader] postgres: {total} rows in audit.events after insert")
    return total


# ---- loki -------------------------------------------------------------------

def _to_ns(ts: str) -> str:
    """Parse 'YYYY-MM-DDTHH:MM:SSZ' (or with offset) -> ns since epoch as str."""
    # Python <3.11 doesn't accept trailing 'Z' in fromisoformat; normalize.
    iso = ts.replace("Z", "+00:00")
    dt = datetime.fromisoformat(iso).astimezone(timezone.utc)
    return str(int(dt.timestamp() * 1_000_000_000))


def push_loki(records: list[dict]) -> int:
    # Group by (source_system, source_type) only. `result` lives inside the JSON
    # line and is queryable via `| json | result="FAILURE"`. Keeping the stream
    # cardinality low avoids a Loki 3.x ingestion quirk where some sparse
    # streams get silently dropped.
    streams: dict[tuple[str, str], list[tuple[str, str]]] = defaultdict(list)
    for r in records:
        key = (r["source_system"], r["source_type"])
        streams[key].append((_to_ns(r["timestamp_utc"]), json.dumps(r, separators=(",", ":"))))

    payload_streams = []
    for (source_system, source_type), values in streams.items():
        # Loki requires entries within a stream sorted by timestamp ascending.
        values.sort(key=lambda v: int(v[0]))
        payload_streams.append({
            "stream": {
                "source_system": source_system,
                "source_type": source_type,
                "job": "medreg-audit-demo",
            },
            "values": [[ts, line] for ts, line in values],
        })

    # Push each stream in its own request — easier to spot per-stream failures
    # if they ever happen (vs a single batched push that returns 204 even when
    # it silently drops a sub-stream).
    pushed = 0
    for s in payload_streams:
        resp = requests.post(
            f"{LOKI_URL}/loki/api/v1/push",
            data=json.dumps({"streams": [s]}),
            headers={"Content-Type": "application/json"},
            timeout=30,
        )
        if resp.status_code >= 300:
            raise RuntimeError(
                f"loki push failed for stream {s['stream']}: "
                f"{resp.status_code} {resp.text[:300]}"
            )
        pushed += len(s["values"])
    print(f"[loader] loki:    pushed {pushed} entries across {len(payload_streams)} streams")
    return pushed


# ---- main -------------------------------------------------------------------

def main() -> int:
    if not DATA_FILE.exists():
        print(f"[loader] FATAL: {DATA_FILE} not found (mount input-docs/?)", file=sys.stderr)
        return 2

    records = json.loads(DATA_FILE.read_text())
    print(f"[loader] read {len(records)} records from {DATA_FILE}")

    wait_for_postgres()
    wait_for_loki()

    # Idempotency check: if Postgres already has events, assume Loki is also
    # populated (they're loaded as a pair) and skip. Use `down -v` for a true
    # reset; this branch just makes routine `up -d` cheap and dupe-free.
    with psycopg.connect(PG_DSN) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT count(*) FROM audit.events")
            (existing,) = cur.fetchone()
    if existing > 0:
        print(f"[loader] postgres already has {existing} events — skipping load (use `down -v` to reset)")
        return 0

    fill_postgres(records)
    push_loki(records)

    print(f"[loader] loaded {len(records)} events")
    return 0


if __name__ == "__main__":
    sys.exit(main())
