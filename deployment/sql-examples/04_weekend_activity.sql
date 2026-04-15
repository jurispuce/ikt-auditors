-- 04 — Brīvdienu aktivitāte / Weekend activity
-- PD#8 stratēģija A.4 — sestdiena (6) un svētdiena (7) pēc ISODOW.

-- 4.1 Visa brīvdienu aktivitāte, sakārtota laikā
SELECT timestamp_utc,
       to_char(timestamp_utc, 'Day') AS day_name,
       user_id,
       source_system,
       action,
       resource,
       result
FROM audit.events
WHERE dow_utc IN (6, 7)
ORDER BY timestamp_utc;

-- 4.2 Lietotāji ar brīvdienu darbībām (kuras nav servisa konti)
SELECT user_id,
       count(*) AS weekend_events,
       count(*) FILTER (WHERE result = 'SUCCESS') AS ok,
       count(*) FILTER (WHERE result <> 'SUCCESS') AS not_ok
FROM audit.events
WHERE dow_utc IN (6, 7)
  AND user_id NOT LIKE 'svc\_%' ESCAPE '\'
  AND user_id <> 'SYSTEM'
GROUP BY user_id
ORDER BY weekend_events DESC;
