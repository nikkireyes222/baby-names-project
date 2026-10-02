-- Name length analysis over time, combined and by gender
-- Source table: example-501820.babynames.names_all
--   Columns: name, assigned_sex_at_birth, count, year
--
-- Each result row is keyed by (year, gender). `gender` is one of
-- 'All', 'F', or 'M' -- GROUPING SETS produces the combined "All" row
-- and the per-gender rows in a single query, so a future app can let a
-- user pick a year and toggle between combined / girls / boys views.

-- 1. % of babies whose name falls into each length bucket, per year
--    and gender. Weighted by `count` (number of babies), not by
--    unique name.
WITH
name_length AS (
  SELECT *, LENGTH(name) AS totalletters
  FROM `example-501820.babynames.names_all`
),

buckets AS (
  SELECT
    year,
    COALESCE(assigned_sex_at_birth, 'All') AS gender,
    SUM(CASE WHEN totalletters IN (1, 2, 3) THEN count END) AS `1_to_3`,
    SUM(CASE WHEN totalletters IN (4, 5) THEN count END) AS `4_to_5`,
    SUM(CASE WHEN totalletters IN (6, 7, 8, 9) THEN count END) AS `6_to_9`,
    SUM(CASE WHEN totalletters IN (10, 11, 12, 13, 14, 15) THEN count END) AS `10_to_15`,
    SUM(CASE WHEN totalletters >= 16 THEN count END) AS `16_plus`,
    SUM(count) AS total
  FROM name_length
  GROUP BY GROUPING SETS ((year, assigned_sex_at_birth), (year))
)

SELECT
  year,   -- key
  gender, -- key ('All', 'F', 'M')
  ROUND(SAFE_DIVIDE(`1_to_3`, total) * 100, 1)   AS pct_1_to_3,
  ROUND(SAFE_DIVIDE(`4_to_5`, total) * 100, 1)   AS pct_4_to_5,
  ROUND(SAFE_DIVIDE(`6_to_9`, total) * 100, 1)   AS pct_6_to_9,
  ROUND(SAFE_DIVIDE(`10_to_15`, total) * 100, 1) AS pct_10_to_15,
  ROUND(SAFE_DIVIDE(`16_plus`, total) * 100, 1)  AS pct_16_plus
FROM buckets
ORDER BY year, gender;


-- 2. Average and max name length per year and gender.
--    `average_length` is weighted by count (SUM(len*count)/SUM(count)),
--    reflecting the length experienced by the average baby, not just
--    the average across unique name spellings.
--    `max_length` is the longest name on record (unweighted, since it
--    only takes one baby to set the max).
WITH
name_length AS (
  SELECT *, LENGTH(name) AS totalletters
  FROM `example-501820.babynames.names_all`
)

SELECT
  year,                                  -- key
  COALESCE(assigned_sex_at_birth, 'All') AS gender, -- key ('All', 'F', 'M')
  ROUND(SUM(totalletters * count) / SUM(count), 2) AS average_length,
  MAX(totalletters) AS max_length
FROM name_length
GROUP BY GROUPING SETS ((year, assigned_sex_at_birth), (year))
ORDER BY year, gender;
