-- Top names analysis
-- Source table: example-501820.babynames.names_all
--   Columns: name, assigned_sex_at_birth, count, year
--
-- "Top" = top 10 names per year, per gender, ranked by count.
-- Results are keyed by (year, gender) / (gender, name) for use in a
-- future app.

-- 1. Top 10 girl and boy names for every year.
WITH ranked AS (
  SELECT
    year,
    assigned_sex_at_birth AS gender,
    name,
    count,
    RANK() OVER (PARTITION BY year, assigned_sex_at_birth ORDER BY count DESC) AS rank
  FROM `example-501820.babynames.names_all`
)

SELECT year, gender, rank, name, count
FROM ranked
WHERE rank <= 10
ORDER BY year, gender, rank;


-- 2. Names that stay in the top 10 the longest.
--    total_years_in_top10: number of years the name was in the top 10.
--    longest_streak: most consecutive years in the top 10
--    (gaps-and-islands: year minus row number is constant within a streak).
WITH ranked AS (
  SELECT
    year,
    assigned_sex_at_birth AS gender,
    name,
    RANK() OVER (PARTITION BY year, assigned_sex_at_birth ORDER BY count DESC) AS rank
  FROM `example-501820.babynames.names_all`
),

top10 AS (
  SELECT year, gender, name FROM ranked WHERE rank <= 10
),

streaks AS (
  SELECT
    gender,
    name,
    year,
    year - ROW_NUMBER() OVER (PARTITION BY gender, name ORDER BY year) AS streak_id
  FROM top10
),

streak_lengths AS (
  SELECT
    gender,
    name,
    COUNT(*) AS streak_years,
    MIN(year) AS streak_start,
    MAX(year) AS streak_end
  FROM streaks
  GROUP BY gender, name, streak_id
)

SELECT
  gender,
  name,
  SUM(streak_years) AS total_years_in_top10,
  MIN(streak_start) AS first_year_in_top10,
  MAX(streak_end) AS last_year_in_top10,
  MAX(streak_years) AS longest_streak
FROM streak_lengths
GROUP BY gender, name
ORDER BY total_years_in_top10 DESC, longest_streak DESC
LIMIT 20;
