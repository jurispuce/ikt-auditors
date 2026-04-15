-- 03 — Aktivitāte ārpus darba laika / Off-hours activity
-- PD#8 stratēģija A.3 — events outside 06:00–18:00 UTC.
-- Atgādinājums: lieto timestamp_utc, NEVIS timestamp_raw!

-- 3.1 Visi LOGIN ārpus darba laika
SELECT timestamp_utc,
       hour_utc,
       user_id,
       user_ip,
       source_system,
       result
FROM audit.events
WHERE action = 'LOGIN'
  AND (hour_utc < 6 OR hour_utc > 18)
ORDER BY timestamp_utc;

-- 3.2 Lietotāji ar visvairāk ārpusdarba aktivitāti
SELECT user_id,
       count(*) AS off_hours_events,
       array_agg(DISTINCT action) AS actions
FROM audit.events
WHERE hour_utc < 6 OR hour_utc > 18
GROUP BY user_id
ORDER BY off_hours_events DESC
LIMIT 15;

-- 3.3 Karstā karte: stundas × dienas pa nedēļas dienai
SELECT hour_utc,
       dow_utc,
       count(*) AS events
FROM audit.events
GROUP BY hour_utc, dow_utc
ORDER BY hour_utc, dow_utc;
