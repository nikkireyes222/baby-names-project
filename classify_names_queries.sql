
-- classified names over time
SELECT n.year,theme, SUM(n.count) AS babies
FROM `example-501820.babynames.names_all` n
JOIN `example-501820.babynames.name_themes` t USING (name)
--WHERE t.theme = 'nature'
GROUP BY n.year, theme ORDER BY n.year;


