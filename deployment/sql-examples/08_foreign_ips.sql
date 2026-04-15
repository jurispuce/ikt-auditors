-- 08 — Aizdomīgas (ārējas) IP adreses / Foreign IPs
-- PD#8 stratēģija B.4 — viss, kas nav 10.0.0.0/8 vai 192.168.0.0/16.
-- Datu vārdnīcā uzskaitītie aizdomīgie diapazoni: Tor exit nodes, Maskavas IP.

-- 8.1 Visi notikumi no ārējām IP
SELECT timestamp_utc,
       user_id,
       user_ip,
       source_system,
       action,
       resource,
       result
FROM audit.events
WHERE user_ip IS NOT NULL
  AND NOT (user_ip << inet '10.0.0.0/8'
        OR user_ip << inet '192.168.0.0/16')
ORDER BY timestamp_utc;

-- 8.2 Ārējās IP grupētas pēc lietotāja
SELECT user_id,
       user_ip,
       count(*) AS events,
       min(timestamp_utc) AS first_seen,
       max(timestamp_utc) AS last_seen
FROM audit.events
WHERE user_ip IS NOT NULL
  AND NOT (user_ip << inet '10.0.0.0/8'
        OR user_ip << inet '192.168.0.0/16')
GROUP BY user_id, user_ip
ORDER BY events DESC;

-- 8.3 Konkrēti datu vārdnīcā minētie aizdomīgie diapazoni (Tor / Maskava)
SELECT timestamp_utc, user_id, user_ip, action, result, resource
FROM audit.events
WHERE user_ip IN (
        inet '185.220.101.42',
        inet '5.188.206.15',
        inet '45.95.169.73',
        inet '5.45.196.120'
      )
ORDER BY timestamp_utc;
