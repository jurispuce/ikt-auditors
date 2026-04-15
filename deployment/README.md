# MedReg audit-log demo deployment

Docker-based teaching environment for the **PD#8 — Auditācijas pierakstu analīze** exercise.
Loads the same `medreg_audit_logs.json` (823 events) into both **Postgres** (for SQL exploration)
and **Loki** (for log-style search), and serves a pre-built **Grafana** dashboard that surfaces
every anomaly category from the exercise brief.

```
┌────────────┐      ┌────────────┐
│  Grafana   │◄─────│ Postgres   │  SQL datasource (panels + Adminer)
│ :3000      │      │ :5432      │
│            │◄─────│   Loki     │  LogQL datasource (logs panel)
└────────────┘      │ :3100      │
                    └────────────┘
                          ▲
                    ┌─────┴─────┐
                    │  loader   │  one-shot Python container
                    │ (exits 0) │  reads JSON → fills PG + Loki
                    └───────────┘
┌────────────┐
│  Adminer   │──► Postgres  (web SQL workbench, port 8080)
└────────────┘
```

---

## 1. Prerequisites

- **Docker Desktop** (or Docker Engine + Compose v2) running.
- Free local ports: **3100** (Loki), **5432** (Postgres). Grafana and Adminer
  bind to **random** ephemeral host ports by default — see *URLs and credentials*
  below for how to discover them. Pin them by setting `GRAFANA_PORT` / `ADMINER_PORT`
  in `.env`. Loki and Postgres ports can also be edited in
  [docker-compose.yml](docker-compose.yml) if they conflict.
- ~500 MB free disk for images + small Postgres/Loki volumes.

---

## 2. Quickstart

```bash
cd deployment
cp .env.example .env          # edit if you want non-default passwords
docker compose up -d --build  # --build only needed the first time
```

Watch the loader finish (it's a one-shot container that exits 0):

```bash
docker compose logs -f loader
```

You should see:

```
[loader] read 823 records from /data/medreg_audit_logs.json
[loader] postgres ready
[loader] loki ready
[loader] postgres: 823 rows in audit.events after insert
[loader] loki:    pushed 823 entries across N streams
[loader] loaded 823 events
```

`loader` then exits — that's normal. The other 4 containers stay up.

Verify everything's healthy:

```bash
docker compose ps
```

All five rows should show `running`/`healthy` except `loader` which is `exited (0)`.

---

## 3. URLs and credentials

Grafana and Adminer bind to **random** ephemeral host ports by default
(so multiple students / instances don't fight over 3000/8080). Discover them with:

```bash
docker compose port grafana 3000   # → 0.0.0.0:54321  (example)
docker compose port adminer 8080   # → 0.0.0.0:54322  (example)
```

Or print all of them at once:

```bash
make urls          # if you have GNU make installed
# or:
for s in grafana adminer loki postgres; do
  printf '%-9s %s\n' "$s" "$(docker compose port "$s" $(case $s in grafana) echo 3000;; adminer) echo 8080;; loki) echo 3100;; postgres) echo 5432;; esac))"
done
```

| Service  | URL (default mapping)                | Login                              |
|----------|--------------------------------------|------------------------------------|
| Grafana  | `http://<host>:<random>`             | `admin` / `admin` (or your `.env`) |
| Adminer  | `http://<host>:<random>`             | see Adminer section below          |
| Loki     | <http://localhost:3100>              | API only (use Grafana → Explore)   |
| Postgres | `localhost:5432`                     | `medreg` / `medreg` / db `medreg`  |

`<host>` is `localhost` from the Docker host itself, or the host's LAN IP
(e.g. `192.168.1.42`) from another machine — the ports are bound to `0.0.0.0`,
so they're reachable from anywhere that can reach the Docker host on those ports.

> **Pinning ports.** If you'd rather use fixed ports, set `GRAFANA_PORT=3000`
> and/or `ADMINER_PORT=8080` in `.env` and `docker compose up -d`.

> **⚠ Security note.** Random ports are bound to **all interfaces**, not just
> `localhost`. On an untrusted network (café Wi-Fi, public hotel LAN), anyone
> who can reach your machine on the assigned port can hit Grafana (anonymous
> viewer is enabled by default) and Adminer's login page. For classroom use
> on a trusted LAN that's the point; on a hostile network either firewall the
> ports, change `GF_AUTH_ANONYMOUS_ENABLED=false`, or stop the stack when not
> demoing.

> **Anonymous Grafana viewing** is enabled — students can open the dashboard
> without logging in. Login is only needed to edit panels / add datasources.

---

## 4. Grafana walkthrough

Open <http://localhost:3000>. The **MedReg Audit Overview** dashboard is the default home.
Time range is pinned to **2026-03-01 → 2026-04-01** (the data window).
The `Source system` dropdown at the top filters every panel.

| # | Panel                              | Maps to brief strategy            | What it teaches                                    |
|---|------------------------------------|-----------------------------------|----------------------------------------------------|
| 1 | Events by `source_system` (donut)  | Phase 2                           | Distribution across the 5 systems.                 |
| 2 | Events over time (stacked bars)    | Phase 2                           | Volume per hour, gaps, bursts.                     |
| 3 | Result breakdown (SUCCESS/FAILURE/ERROR) | Phase 2                     | Overall failure %.                                 |
| 4 | Top 15 users by event count        | Phase 2                           | Heavy hitters; `SYSTEM` and svc accounts dominate. |
| 5 | **Off-hours LOGINs** (UTC<6 or >18)| A.3                               | Sessions outside business hours.                   |
| 6 | **Top exports** (rows_exported / rows_affected) | A.5                  | Bulk data movement.                                |
| 7 | **Foreign IPs** (NOT 10/8 / 192.168/16) | B.4                          | External / Tor / suspicious source IPs.            |
| 8 | **Failed LOGINs per IP**           | A.2                               | Brute-force / credential-stuffing signal.          |
| 9 | **Live log search (Loki)**         | bonus — SIEM feel                 | LogQL: `{job="medreg-audit-demo"}`                 |

### LogQL examples to try in Grafana → Explore → datasource **Loki**

Stream labels are `{source_system, source_type, job}`. Everything else
(`result`, `user_id`, `action`, `rows_affected`, …) lives inside the JSON
line and is unlocked by `| json`.

```logql
# all events for one system
{source_system="VDRIS-DB-PROD"}

# heavy DB operations
{source_system="VDRIS-DB-PROD"} | json | rows_affected > 100

# every failed event, any source
{job="medreg-audit-demo"} | json | result="FAILURE"

# failed logins only
{source_type="authentication"} | json | action="LOGIN" | result="FAILURE"

# events from a specific user
{job="medreg-audit-demo"} | json | user_id="j.kalnins"

# hourly volume per source
sum by (source_system) (count_over_time({job="medreg-audit-demo"}[1h]))
```

> **Note on Loki time range:** because the demo data is dated **March 2026**,
> set the time picker to **Last 5 years** (or absolute 2026-03-01 → 2026-04-01)
> when in Explore. Default "Last 1 hour" will show nothing.

---

## 5. SQL workbench (Adminer)

Open <http://localhost:8080>.

| Field    | Value         |
|----------|---------------|
| System   | PostgreSQL    |
| Server   | `postgres`    |
| Username | `medreg`      |
| Password | `medreg`      |
| Database | `medreg`      |

Click **SQL command** in the left panel, paste any file from [`sql-examples/`](sql-examples/),
and click **Execute**. The numbered files map to the brief's strategies:

| File                                                                    | Brief strategy | Purpose                                          |
|-------------------------------------------------------------------------|----------------|--------------------------------------------------|
| [`01_basic_counts.sql`](sql-examples/01_basic_counts.sql)               | Phase 2        | Counts, time range, distinct users, FAILURE %.   |
| [`02_failed_logins.sql`](sql-examples/02_failed_logins.sql)             | A.2            | Top IPs / users + sliding-window burst detect.   |
| [`03_off_hours.sql`](sql-examples/03_off_hours.sql)                     | A.3            | Hour-of-day filtering using generated columns.   |
| [`04_weekend_activity.sql`](sql-examples/04_weekend_activity.sql)       | A.4            | Weekend events, excluding service accounts.      |
| [`05_large_exports.sql`](sql-examples/05_large_exports.sql)             | A.5            | `details->>'rows_exported'` JSONB extraction.    |
| [`06_multi_ip_users.sql`](sql-examples/06_multi_ip_users.sql)           | B.1            | Multi-IP users + "impossible travel" via `LEAD`. |
| [`07_service_account_misuse.sql`](sql-examples/07_service_account_misuse.sql) | B.2     | `svc_*` accounts doing human-like actions.       |
| [`08_foreign_ips.sql`](sql-examples/08_foreign_ips.sql)                 | B.4            | INET CIDR filtering with `<<` operator.          |
| [`09_ex_employee_logins.sql`](sql-examples/09_ex_employee_logins.sql)   | A.1            | `_old` / `_ex` accounts still active.            |
| [`10_db_without_auth.sql`](sql-examples/10_db_without_auth.sql)         | B.3            | `LEFT JOIN` to find DB ops without prior LOGIN.  |
| [`11_dormant_then_active.sql`](sql-examples/11_dormant_then_active.sql) | C.1            | 7-day baseline window for activity spike.        |

### psql alternative (no browser)

```bash
docker compose exec postgres psql -U medreg -d medreg \
  -f /sql-examples/03_off_hours.sql
```

The `sql-examples/` folder is mounted read-only into the postgres container at
`/sql-examples/`, so any file you add locally is immediately runnable inside.

### Connect from a desktop client (DBeaver, DataGrip, …)

Host `localhost`, port `5432`, db `medreg`, user `medreg`, password `medreg`.
A read-only role `auditor_ro` / `auditor_ro` also exists — that's what Grafana uses,
and it's what to hand out to students if you want to prevent accidental writes.

---

## 6. End-to-end suggested classroom flow (~10 min)

1. Show students the JSON file in [`../input-docs/`](../input-docs/) — the same source
   they'd open in Excel.
2. `docker compose up -d` — show that one command boots the full stack.
3. Open Grafana, walk through panels 1–8 — call out which exercise anomaly each surfaces.
4. Switch to Adminer, run [`02_failed_logins.sql`](sql-examples/02_failed_logins.sql) §2.3
   (sliding window) — show how SQL window functions express something Excel struggles with.
5. Switch to Grafana → Explore → Loki, run `{result="FAILURE"} | json` — show the
   "SIEM feel" of structured-log search.
6. Reflection — *which questions were easiest in which tool?* (Grafana for visual scan,
   SQL for joins / windows, Loki for free-text drill-down.)

---

## 7. Operations

| What                                           | Command                                                  |
|------------------------------------------------|----------------------------------------------------------|
| Full reset (wipes Postgres + Loki volumes)     | `docker compose down -v && docker compose up -d`         |
| Re-run loader only (idempotent)                | `docker compose up -d --force-recreate loader`           |
| Tail Grafana logs                              | `docker compose logs -f grafana`                         |
| Open psql shell                                | `docker compose exec postgres psql -U medreg -d medreg`  |
| Stop everything (keep data)                    | `docker compose stop`                                    |
| Stop + remove containers (keep data)           | `docker compose down`                                    |
| Stop + remove containers AND data              | `docker compose down -v`                                 |

The JSON file is **mounted read-only** from `../input-docs/` — the deployment never
writes back. To experiment with modified data, edit the JSON, then `down -v` and `up -d`.

---

## 8. Troubleshooting

| Symptom                                                | Cause / fix                                                                                       |
|--------------------------------------------------------|---------------------------------------------------------------------------------------------------|
| `bind: address already in use` on `up`                 | Another service is using 3000/3100/5432/8080. Edit the host-side port in `docker-compose.yml`.    |
| Loader logs `loki not ready` repeatedly                | Loki needs 10–30 s to warm up. The retry loop runs for 2 min — wait it out.                       |
| Grafana panels show "No data"                          | Time range. Set absolute **2026-03-01 → 2026-04-01** (data is dated March 2026).                  |
| Grafana → Explore → Loki shows nothing                 | Same — switch time picker to **Last 5 years** or the March 2026 window.                           |
| `permission denied` mounting `../input-docs/`          | macOS: ensure the project folder is granted to Docker in *Settings → Resources → File Sharing*.   |
| `audit.events` is empty after `up -d`                  | Did the loader exit 0? `docker compose logs loader`. If it failed, fix and `up -d --force-recreate loader`. |
| `loki` errors `entry too far behind`                   | The Loki config sets `reject_old_samples: false`. If you swapped configs, restore that flag.      |
| Need to re-create the dashboard after editing the JSON | `docker compose restart grafana` — provisioning re-reads `/var/lib/grafana/dashboards/`.          |

---

## 9. What's where (file map)

```
deployment/
├── docker-compose.yml              # 5 services + 3 named volumes
├── .env.example                    # copy → .env
├── postgres/init/01_schema.sql     # audit.events + indexes + auditor_ro role
├── loader/                         # one-shot ingester (PG + Loki)
├── loki/loki-config.yml            # filesystem-backed single-binary Loki
├── grafana/
│   ├── provisioning/datasources/   # Postgres + Loki, auto-loaded
│   ├── provisioning/dashboards/    # provider pointing at /var/lib/grafana/dashboards
│   └── dashboards/audit-overview.json   # the 9-panel dashboard
├── sql-examples/                   # 11 numbered SQL files (mounted into postgres)
└── README.md                       # this file
```
