-- 11 — "Snaudošie" konti, kas pēkšņi kļūst aktīvi / Dormant-then-active accounts
-- PD#8 stratēģija C.1 — lietotāji ar niecīgu aktivitāti, kas pēkšņi pieaug.
-- Heuristika: 7 dienu sliding window — atrod gadījumus, kad lietotāja
-- aktivitāte pēdējās 24h ir > 5x lielāka par vidējo iepriekšējās 7 dienās.

WITH daily AS (
    SELECT user_id,
           date_trunc('day', timestamp_utc)::date AS day,
           count(*) AS events
    FROM audit.events
    GROUP BY user_id, day
),
with_baseline AS (
    SELECT user_id,
           day,
           events,
           avg(events) OVER (
               PARTITION BY user_id
               ORDER BY day
               ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING
           ) AS baseline_7d
    FROM daily
)
SELECT user_id,
       day,
       events,
       round(baseline_7d::numeric, 2) AS baseline_7d,
       CASE
           WHEN baseline_7d IS NULL OR baseline_7d = 0 THEN NULL
           ELSE round((events / baseline_7d)::numeric, 2)
       END AS spike_ratio
FROM with_baseline
WHERE baseline_7d IS NOT NULL
  AND baseline_7d > 0
  AND events > 5 * baseline_7d
ORDER BY spike_ratio DESC NULLS LAST;
