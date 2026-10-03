-- Exploratory queries
-- Tables: example-501820.babynames.names_all    (name, assigned_sex_at_birth, count, year)
--         example-501820.babynames.name_themes  (name, theme, confidence, reason, model)
-- Run in the BigQuery console: https://console.cloud.google.com/bigquery?project=example-501820
-- Tips: wrap table names in backticks, add LIMIT while exploring, and use percentages
-- (not raw counts) to compare eras, since early years are undercounted.

-- 1. Babies per year with a nature name (raw counts).
SELECT n.year, SUM(n.count) AS babies
FROM `example-501820.babynames.names_all` n
JOIN `example-501820.babynames.name_themes` t USING (name)
WHERE t.theme = 'nature'
GROUP BY n.year
ORDER BY n.year;


-- 2. Rank of one name over time (change the name and gender).
SELECT year, name, count, rank
FROM (
  SELECT year, name, count,
    RANK() OVER (PARTITION BY year, assigned_sex_at_birth ORDER BY count DESC) AS rank
  FROM `example-501820.babynames.names_all`
  WHERE assigned_sex_at_birth = 'F'
)
WHERE name = 'Violet'
ORDER BY year;


-- 3. Name concentration: share of babies given one of that year's top 10 names, by gender.
--    A falling line means names are getting more diverse.
WITH ranked AS (
  SELECT year, assigned_sex_at_birth AS gender, count,
    RANK() OVER (PARTITION BY year, assigned_sex_at_birth ORDER BY count DESC) AS rank
  FROM `example-501820.babynames.names_all`
)
SELECT
  year, gender,
  ROUND(SUM(IF(rank <= 10, count, 0)) / SUM(count) * 100, 1) AS pct_babies_in_top10
FROM ranked
GROUP BY year, gender
ORDER BY year, gender;


-- 4. Number of distinct names per year, by gender (naming variety).
SELECT year, assigned_sex_at_birth AS gender, COUNT(DISTINCT name) AS distinct_names
FROM `example-501820.babynames.names_all`
GROUP BY year, gender
ORDER BY year, gender;


-- 5. Gender-neutral names: names given to both girls and boys in the same year,
--    with the share going to girls. Closer to 50 = more evenly split.
SELECT
  year, name,
  SUM(IF(assigned_sex_at_birth = 'F', count, 0)) AS girls,
  SUM(IF(assigned_sex_at_birth = 'M', count, 0)) AS boys,
  ROUND(SUM(IF(assigned_sex_at_birth = 'F', count, 0)) / SUM(count) * 100, 1) AS pct_girls
FROM `example-501820.babynames.names_all`
WHERE year = 2025
GROUP BY year, name
HAVING girls >= 500 AND boys >= 500
ORDER BY ABS(50 - pct_girls), girls + boys DESC
LIMIT 25;


-- 6. Names that flipped gender: mostly given to one sex in 1920 but the other in 2025.
--    Uses names with 300+ babies in both years (change the years/threshold to explore).
WITH by_year AS (
  SELECT name, year,
    SUM(IF(assigned_sex_at_birth = 'F', count, 0)) AS girls,
    SUM(IF(assigned_sex_at_birth = 'M', count, 0)) AS boys
  FROM `example-501820.babynames.names_all`
  WHERE year IN (1920, 2025)
  GROUP BY name, year
)
SELECT a.name, a.girls AS girls_1920, a.boys AS boys_1920, b.girls AS girls_2025, b.boys AS boys_2025
FROM by_year a
JOIN by_year b ON a.name = b.name AND a.year = 1920 AND b.year = 2025
WHERE a.girls + a.boys >= 300 AND b.girls + b.boys >= 300
  AND (a.girls > a.boys) != (b.girls > b.boys)
ORDER BY b.girls + b.boys DESC
LIMIT 25;


-- 7. Biggest one-year jumps: names whose count grew the most from 2024 to 2025.
WITH cur AS (
  SELECT name, assigned_sex_at_birth AS gender, year, count
  FROM `example-501820.babynames.names_all`
  WHERE year IN (2024, 2025)
)
SELECT
  name, gender,
  SUM(IF(year = 2024, count, 0)) AS count_2024,
  SUM(IF(year = 2025, count, 0)) AS count_2025,
  SUM(IF(year = 2025, count, 0)) - SUM(IF(year = 2024, count, 0)) AS change
FROM cur
GROUP BY name, gender
HAVING count_2024 >= 100
ORDER BY change DESC
LIMIT 20;


-- 8. Share of babies by theme (nature / religion / other) for a chosen year.
--    Names under 1000 babies total were not classified and are excluded here.
SELECT
  t.theme,
  SUM(n.count) AS babies,
  ROUND(SUM(n.count) / SUM(SUM(n.count)) OVER () * 100, 1) AS pct_of_classified_babies
FROM `example-501820.babynames.names_all` n
JOIN `example-501820.babynames.name_themes` t USING (name)
WHERE n.year = 2025
GROUP BY t.theme
ORDER BY babies DESC;


-- 9. Most popular names in a theme for a decade (change theme and years).
SELECT n.name, SUM(n.count) AS babies
FROM `example-501820.babynames.names_all` n
JOIN `example-501820.babynames.name_themes` t USING (name)
WHERE t.theme = 'nature' AND n.year BETWEEN 2010 AND 2019 AND t.confidence >= 0.9
GROUP BY n.name
ORDER BY babies DESC
LIMIT 15;


-- 10. Starting letter trends: share of babies per first letter for one year.
SELECT
  UPPER(SUBSTR(name, 1, 1)) AS first_letter,
  SUM(count) AS babies,
  ROUND(SUM(count) / SUM(SUM(count)) OVER () * 100, 1) AS pct_of_babies
FROM `example-501820.babynames.names_all`
WHERE year = 2025
GROUP BY first_letter
ORDER BY babies DESC;
