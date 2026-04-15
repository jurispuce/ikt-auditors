-- 07 — Servisa kontu (ne)pareiza lietošana / Service account misuse
-- PD#8 stratēģija B.2 — `svc_*` konti ar cilvēka tipa darbībām (web_app VIEW/SEARCH).

-- 7.1 Visas servisa kontu darbības, sadalītas pa avotu tipu
SELECT user_id,
       source_type,
       action,
       count(*) AS events
FROM audit.events
WHERE user_id LIKE 'svc\_%' ESCAPE '\'
GROUP BY user_id, source_type, action
ORDER BY user_id, events DESC;

-- 7.2 Servisa konti ar darbībām, kas izskatās pēc cilvēka aktivitātes
SELECT timestamp_utc,
       user_id,
       user_ip,
       source_system,
       action,
       resource
FROM audit.events
WHERE user_id LIKE 'svc\_%' ESCAPE '\'
  AND (
        source_type = 'web_app' AND action IN ('VIEW', 'SEARCH', 'GET')
        OR resource LIKE '/admin/%'
        OR resource LIKE '%export%'
      )
ORDER BY timestamp_utc;

-- 7.3 Servisa konti, kas pieslēdzas neparastās stundās (paši servisi parasti strādā 24/7,
-- bet, ja viens svc konts pēkšņi parādās tikai darba laikā — interesants signāls)
SELECT user_id,
       count(*) FILTER (WHERE hour_utc BETWEEN  6 AND 18) AS business_hours,
       count(*) FILTER (WHERE hour_utc <  6 OR  hour_utc > 18) AS off_hours
FROM audit.events
WHERE user_id LIKE 'svc\_%' ESCAPE '\'
GROUP BY user_id
ORDER BY user_id;
