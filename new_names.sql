-- 2025 top-100 names (per gender) that were never in a top 50 (same gender) before 2025,
-- classified by how popular they were in earlier eras.
WITH ranked AS (
  SELECT year, assigned_sex_at_birth AS gender, name, count,
    RANK() OVER (PARTITION BY year, assigned_sex_at_birth ORDER BY count DESC) AS rank
  FROM `example-501820.babynames.names_all`
),

history AS (
  SELECT
    gender, name,
    MIN(year) AS first_year,
    MIN(rank) AS best_prior_rank,
    MIN(IF(year < 1960, rank, NULL)) AS best_rank_pre_1960,
    MIN(IF(year BETWEEN 1990 AND 2004, rank, NULL)) AS best_rank_1990_2004,
    MIN(IF(year BETWEEN 2005 AND 2014, rank, NULL)) AS best_rank_2005_2014
  FROM ranked
  WHERE year < 2025
  GROUP BY gender, name
),

new_2025 AS (
  SELECT r.gender, r.name, r.rank AS rank_2025, r.count AS count_2025
  FROM ranked r
  LEFT JOIN history h USING (gender, name)
  WHERE r.year = 2025 AND r.rank <= 100
    AND (h.best_prior_rank IS NULL OR h.best_prior_rank > 50)
)

SELECT
  n.gender, n.name, n.rank_2025, n.count_2025,
  h.first_year,
  h.best_rank_pre_1960,
  h.best_rank_1990_2004,
  h.best_rank_2005_2014,
  CASE
    WHEN h.first_year IS NULL OR h.first_year >= 2000
      THEN 'Brand new (first appeared 2000+)'
    WHEN h.best_rank_pre_1960 <= 200 AND COALESCE(h.best_rank_1990_2004, 99999) > 300
      THEN 'Revival (popular before 1960, faded by 1990s, now back)'
    WHEN COALESCE(h.best_rank_2005_2014, 99999) > 150
      THEN 'Recent breakout (outside top 150 as recently as 2005-2014)'
    ELSE 'Steady climber (already top 150 in 2005-2014)'
  END AS category
FROM new_2025 n
LEFT JOIN history h USING (gender, name)
ORDER BY category, n.gender, n.rank_2025
