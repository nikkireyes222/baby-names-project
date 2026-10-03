-- Name themes over time: nature vs religion
-- Sources: example-501820.babynames.names_all  (name, assigned_sex_at_birth, count, year)
--          example-501820.babynames.name_themes (name, theme, confidence, reason, model)
--          name_themes is built by classify_names.py (LangChain + Claude), so no
--          hard-coded name lists are needed here.
--
-- Coverage note: only names with >= 1000 babies total were classified (about 97% of
-- all babies). Unclassified names count in the total but not in any theme.
--
-- Results are keyed by (year, gender, theme). gender is 'All', 'F' or 'M'.

WITH tagged AS (
  SELECT n.year, n.assigned_sex_at_birth AS sex, t.theme, n.count
  FROM `example-501820.babynames.names_all` n
  JOIN `example-501820.babynames.name_themes` t USING (name)
  WHERE t.theme IN ('nature', 'religion')
),

theme_counts AS (
  SELECT year, sex, theme, SUM(count) AS theme_babies
  FROM tagged
  GROUP BY GROUPING SETS ((year, sex, theme), (year, theme))
),

totals AS (
  SELECT year, assigned_sex_at_birth AS sex, SUM(count) AS total_babies
  FROM `example-501820.babynames.names_all`
  GROUP BY GROUPING SETS ((year, assigned_sex_at_birth), (year))
)

-- 1. % of babies per year given a nature or religion name, by gender.
SELECT
  c.year,                          -- key
  COALESCE(c.sex, 'All') AS gender, -- key ('All', 'F', 'M')
  c.theme,
  c.theme_babies,
  ROUND(SAFE_DIVIDE(c.theme_babies, t.total_babies) * 100, 2) AS pct_of_babies
FROM theme_counts c
JOIN totals t ON c.year = t.year AND IFNULL(c.sex, '') = IFNULL(t.sex, '')
ORDER BY c.year, gender, c.theme;
