-- 06 — Lietotāji no vairākām IP / Users from multiple IPs
-- PD#8 stratēģija B.1 + "impossible travel" detekcija.

-- 6.1 Lietotāji ar > 1 unikālu IP visā periodā
SELECT user_id,
       count(DISTINCT user_ip)            AS distinct_ips,
       array_agg(DISTINCT user_ip::text)  AS ips
FROM audit.events
WHERE user_ip IS NOT NULL
GROUP BY user_id
HAVING count(DISTINCT user_ip) > 1
ORDER BY distinct_ips DESC;

-- 6.2 "Impossible travel" — divi notikumi no atšķirīgām IP <60 min
WITH consecutive AS (
    SELECT user_id,
           timestamp_utc                           AS t1,
           user_ip                                 AS ip1,
           lead(timestamp_utc) OVER w              AS t2,
           lead(user_ip)       OVER w              AS ip2
    FROM audit.events
    WHERE user_ip IS NOT NULL
    WINDOW w AS (PARTITION BY user_id ORDER BY timestamp_utc)
)
SELECT user_id,
       t1, ip1,
       t2, ip2,
       (t2 - t1) AS gap
FROM consecutive
WHERE ip1 <> ip2
  AND (t2 - t1) < INTERVAL '60 minutes'
ORDER BY user_id, t1;

-- 6.3 Lietotāju IP "fingerprint" — iekšējie vs ārējie
SELECT user_id,
       count(*) FILTER (WHERE user_ip << inet '10.0.0.0/8'
                          OR user_ip << inet '192.168.0.0/16') AS internal,
       count(*) FILTER (WHERE user_ip IS NOT NULL
                          AND NOT (user_ip << inet '10.0.0.0/8'
                                OR user_ip << inet '192.168.0.0/16')) AS external,
       count(*) AS total
FROM audit.events
GROUP BY user_id
HAVING count(*) FILTER (WHERE user_ip IS NOT NULL
                          AND NOT (user_ip << inet '10.0.0.0/8'
                                OR user_ip << inet '192.168.0.0/16')) > 0
ORDER BY external DESC;
