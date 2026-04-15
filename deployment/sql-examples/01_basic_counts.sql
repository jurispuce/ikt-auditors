-- 01 — Sākotnējā izpēte / Basic counts
-- Atbilst PD#8 brīfa 2. fāzei: cik ierakstu, cik unikālu lietotāju, FAILURE %.
-- Maps to PD#8 phase 2 of the exercise brief.

-- 1.1 Ierakstu skaits pa avota sistēmām
SELECT source_system,
       count(*) AS events
FROM audit.events
GROUP BY source_system
ORDER BY events DESC;

-- 1.2 Laika diapazons
SELECT min(timestamp_utc) AS first_event,
       max(timestamp_utc) AS last_event,
       max(timestamp_utc) - min(timestamp_utc) AS span
FROM audit.events;

-- 1.3 Unikālie lietotāji
SELECT count(DISTINCT user_id) AS distinct_users
FROM audit.events;

-- 1.4 FAILURE procents pa avota sistēmām
SELECT source_system,
       count(*)                                      AS total,
       count(*) FILTER (WHERE result = 'FAILURE')    AS failures,
       round(100.0 * count(*) FILTER (WHERE result = 'FAILURE') / count(*), 2) AS failure_pct
FROM audit.events
GROUP BY source_system
ORDER BY failure_pct DESC;
