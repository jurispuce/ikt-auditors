-- 02 — Neveiksmīgas pieslēgšanās / Failed logins
-- PD#8 stratēģija A.2 — brute-force / credential stuffing signāls.

-- 2.1 Top IP adreses pēc neveiksmīgo LOGIN skaita
SELECT user_ip,
       count(*)                  AS failed_logins,
       count(DISTINCT user_id)   AS distinct_users_attempted,
       min(timestamp_utc)        AS first_seen,
       max(timestamp_utc)        AS last_seen
FROM audit.events
WHERE action = 'LOGIN'
  AND result = 'FAILURE'
GROUP BY user_ip
ORDER BY failed_logins DESC
LIMIT 20;

-- 2.2 Top lietotāji pēc neveiksmīgo LOGIN skaita
SELECT user_id,
       count(*)                  AS failed_logins,
       count(DISTINCT user_ip)   AS distinct_source_ips
FROM audit.events
WHERE action = 'LOGIN'
  AND result = 'FAILURE'
GROUP BY user_id
ORDER BY failed_logins DESC
LIMIT 20;

-- 2.3 Sliding window: vairāk nekā 5 neveiksmes 10 minūšu logā no vienas IP
WITH per_ip AS (
    SELECT user_ip,
           timestamp_utc,
           count(*) OVER (
               PARTITION BY user_ip
               ORDER BY timestamp_utc
               RANGE BETWEEN INTERVAL '10 minutes' PRECEDING AND CURRENT ROW
           ) AS window_failures
    FROM audit.events
    WHERE action = 'LOGIN'
      AND result = 'FAILURE'
)
SELECT user_ip, timestamp_utc, window_failures
FROM per_ip
WHERE window_failures >= 5
ORDER BY user_ip, timestamp_utc;
