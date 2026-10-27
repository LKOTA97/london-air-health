-- 02_trends.sql
-- PM2.5 and the share of deaths attributable to PM2.5, 2018 to 2024, for:
--   each of the 33 London areas ('Borough'),
--   London as a population-weighted mean of the 33 areas ('London'),
--   England as published by Fingertips ('England').
-- London is weighted by each year's own mid-year population.

-- PM2.5 (93867) and attributable % (93861) side by side, one row per area and year
WITH air_quality AS (
    SELECT
        area_code,
        year_start AS year,
        MAX(CASE WHEN indicator_id = 93867 THEN value END) AS pm25,
        MAX(CASE WHEN indicator_id = 93861 THEN value END) AS attributable_pct
    FROM indicators
    WHERE indicator_id IN (93867, 93861)
        AND year_start BETWEEN 2018 AND 2024
    GROUP BY area_code, year_start
),

-- Total population per area and year. Summed BEFORE joining, so each
-- air quality row meets exactly one population row (no double counting).
population_total AS (
    SELECT
        area_code,
        year,
        SUM(population) AS population
    FROM population
    GROUP BY area_code, year
),

-- The 33 London areas as published
borough_rows AS (
    SELECT
        aq.year,
        aq.area_code,
        a.area_name,
        'Borough' AS area_group,
        aq.pm25,
        aq.attributable_pct
    FROM air_quality AS aq
    INNER JOIN areas AS a
        ON aq.area_code = a.area_code
    WHERE a.is_london
),

-- London: weighted mean = SUM(value * population) / SUM(population), per year
london_rows AS (
    SELECT
        aq.year,
        'LONDON' AS area_code,
        'London (population-weighted)' AS area_name,
        'London' AS area_group,
        SUM(aq.pm25 * pt.population) / SUM(pt.population) AS pm25,
        SUM(aq.attributable_pct * pt.population) / SUM(pt.population) AS attributable_pct
    FROM air_quality AS aq
    INNER JOIN population_total AS pt
        ON aq.area_code = pt.area_code
        AND aq.year = pt.year
    GROUP BY aq.year
),

-- England as published by Fingertips
england_rows AS (
    SELECT
        aq.year,
        aq.area_code,
        'England' AS area_name,
        'England' AS area_group,
        aq.pm25,
        aq.attributable_pct
    FROM air_quality AS aq
    WHERE aq.area_code = 'E92000001'
)

SELECT year, area_code, area_name, area_group, pm25, attributable_pct FROM borough_rows
UNION ALL
SELECT year, area_code, area_name, area_group, pm25, attributable_pct FROM london_rows
UNION ALL
SELECT year, area_code, area_name, area_group, pm25, attributable_pct FROM england_rows
ORDER BY area_group, area_code, year;
