-- 05 — Lieli datu eksporti / Large data exports
-- PD#8 stratēģija A.5 — `resource = '/api/v2/export'`, sakārto pēc rows_exported.
-- Plus: lielas DB darbības pēc `details.rows_affected`.

-- 5.1 Top eksporti pēc rindu skaita (web app)
SELECT timestamp_utc,
       user_id,
       user_ip,
       resource,
       (details->>'rows_exported')::int AS rows_exported,
       details
FROM audit.events
WHERE details ? 'rows_exported'
ORDER BY rows_exported DESC NULLS LAST
LIMIT 25;

-- 5.2 Top DB darbības pēc skarto rindu skaita
SELECT timestamp_utc,
       user_id,
       source_system,
       action,
       resource,
       (details->>'rows_affected')::int AS rows_affected
FROM audit.events
WHERE details ? 'rows_affected'
ORDER BY rows_affected DESC NULLS LAST
LIMIT 25;

-- 5.3 Eksporti grupēti pa lietotāju un dienu — atkārtoti modeļi
SELECT user_id,
       date_trunc('day', timestamp_utc)::date AS day,
       count(*) AS exports,
       sum((details->>'rows_exported')::int) AS total_rows
FROM audit.events
WHERE details ? 'rows_exported'
GROUP BY user_id, day
ORDER BY total_rows DESC NULLS LAST
LIMIT 20;
