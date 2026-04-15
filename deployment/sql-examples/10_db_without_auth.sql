-- 10 — DB darbības bez autentifikācijas / DB events without prior auth
-- PD#8 stratēģija B.3 — DB ieraksti, kuru lietotājam tajā dienā nav LOGIN ieraksta.
-- Pieņēmums: lietotājs, kas tiešām strādā ar VDRIS-DB-PROD, parasti ir vispirms
-- pieslēdzies caur Windows-DC-01 / VDRIS-AUTH.

WITH db_users_per_day AS (
    SELECT DISTINCT
           user_id,
           date_trunc('day', timestamp_utc)::date AS day
    FROM audit.events
    WHERE source_type = 'database'
),
auth_users_per_day AS (
    SELECT DISTINCT
           user_id,
           date_trunc('day', timestamp_utc)::date AS day
    FROM audit.events
    WHERE source_type = 'authentication'
      AND action = 'LOGIN'
      AND result = 'SUCCESS'
)
SELECT d.user_id,
       d.day,
       count(e.event_id) AS db_events_that_day
FROM db_users_per_day d
LEFT JOIN auth_users_per_day a USING (user_id, day)
JOIN audit.events e
  ON e.user_id = d.user_id
 AND date_trunc('day', e.timestamp_utc)::date = d.day
 AND e.source_type = 'database'
WHERE a.user_id IS NULL
GROUP BY d.user_id, d.day
ORDER BY db_events_that_day DESC;
