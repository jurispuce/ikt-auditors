-- 09 — Bijušo darbinieku konti / Ex-employee accounts
-- PD#8 stratēģija A.1 — `user_id` ar suffix `_old` vai `_ex`.
-- Datu vārdnīca: a.kalnina_old un r.ozols_old NAV deaktivēti (anomālija!),
-- m.berzins_ex IR pareizi deaktivēts (kontrole — nedrīkstētu būt aktivitātes).

-- 9.1 Visa aktivitāte no _old / _ex kontiem
SELECT timestamp_utc,
       user_id,
       user_ip,
       source_system,
       action,
       result
FROM audit.events
WHERE user_id LIKE '%\_old' ESCAPE '\'
   OR user_id LIKE '%\_ex'  ESCAPE '\'
ORDER BY user_id, timestamp_utc;

-- 9.2 Kopsavilkums: cik aktivitātes katram bijušajam kontam
SELECT user_id,
       count(*)                                         AS events,
       count(*) FILTER (WHERE result = 'SUCCESS')       AS success,
       count(*) FILTER (WHERE result = 'FAILURE')       AS failure,
       min(timestamp_utc)                               AS first_event,
       max(timestamp_utc)                               AS last_event
FROM audit.events
WHERE user_id LIKE '%\_old' ESCAPE '\'
   OR user_id LIKE '%\_ex'  ESCAPE '\'
GROUP BY user_id
ORDER BY events DESC;
