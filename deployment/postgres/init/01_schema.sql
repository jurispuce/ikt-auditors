-- MedReg audit-log demo schema
-- Mirrors medreg_audit_logs.json 1:1, with a few generated columns for teaching.

CREATE SCHEMA IF NOT EXISTS audit;

CREATE TABLE IF NOT EXISTS audit.events (
    event_id      TEXT PRIMARY KEY,
    timestamp_utc TIMESTAMPTZ NOT NULL,
    timestamp_raw TEXT        NOT NULL,
    timezone      TEXT        NOT NULL,
    source_system TEXT        NOT NULL,
    source_type   TEXT        NOT NULL,
    user_id       TEXT        NOT NULL,
    user_ip       INET,
    action        TEXT        NOT NULL,
    resource      TEXT,
    result        TEXT        NOT NULL,
    details       JSONB,
    -- Convenience columns so students can filter without writing EXTRACT() everywhere.
    -- Populated by the loader (EXTRACT on TIMESTAMPTZ is not immutable, so generated
    -- columns aren't an option here).
    -- ISODOW: 1 = Monday ... 7 = Sunday
    hour_utc      INT NOT NULL,
    dow_utc       INT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_events_user        ON audit.events (user_id);
CREATE INDEX IF NOT EXISTS idx_events_source_sys  ON audit.events (source_system);
CREATE INDEX IF NOT EXISTS idx_events_time        ON audit.events (timestamp_utc);
CREATE INDEX IF NOT EXISTS idx_events_result      ON audit.events (result);
CREATE INDEX IF NOT EXISTS idx_events_action      ON audit.events (action);
CREATE INDEX IF NOT EXISTS idx_events_details_gin ON audit.events USING GIN (details);

-- Read-only role for Grafana / classroom demos.
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'auditor_ro') THEN
        CREATE ROLE auditor_ro LOGIN PASSWORD 'auditor_ro';
    END IF;
END $$;

GRANT USAGE  ON SCHEMA audit TO auditor_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA audit TO auditor_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit GRANT SELECT ON TABLES TO auditor_ro;
