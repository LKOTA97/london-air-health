-- 03_deprivation_groups.sql
-- Splits the 32 London boroughs (City of London excluded) into thirds by
-- IMD 2025 score with NTILE(3), then gives the mean PM2.5 and attributable %
-- for each third in the latest year. Third 1 is the least deprived.
-- Ecological comparison only: it describes areas, not people.

-- Latest year for the air pollution indicators
WITH latest_year AS (
    SELECT MAX(year_start) AS year_start
    FROM indicators
    WHERE indicator_id = 93867
),

-- One row per borough: IMD 2025 score, PM2.5 and attributable % in the latest year
borough_values AS (
    SELECT
        a.area_code,
        a.area_name,
        MAX(CASE WHEN i.indicator_id = 94240 THEN i.value END) AS imd_score,
        MAX(CASE WHEN i.indicator_id = 93867 AND i.year_start = ly.year_start THEN i.value END) AS pm25,
        MAX(CASE WHEN i.indicator_id = 93861 AND i.year_start = ly.year_start THEN i.value END) AS attributable_pct,
        MAX(ly.year_start) AS year
    FROM areas AS a
    INNER JOIN indicators AS i
        ON a.area_code = i.area_code
    CROSS JOIN latest_year AS ly
    WHERE a.is_london
        AND NOT a.is_city_of_london
        AND i.indicator_id IN (94240, 93867, 93861)
    GROUP BY a.area_code, a.area_name
),

-- Thirds by deprivation: NTILE(3) on ascending IMD score, so 3 = most deprived
deprivation_thirds AS (
    SELECT
        area_code,
        area_name,
        imd_score,
        pm25,
        attributable_pct,
        year,
        NTILE(3) OVER (ORDER BY imd_score) AS imd_third
    FROM borough_values
)

SELECT
    imd_third,
    CASE imd_third
        WHEN 1 THEN 'Least deprived third'
        WHEN 2 THEN 'Middle third'
        WHEN 3 THEN 'Most deprived third'
    END AS imd_group,
    COUNT(*) AS n_boroughs,
    MIN(imd_score) AS imd_score_min,
    MAX(imd_score) AS imd_score_max,
    AVG(pm25) AS mean_pm25,
    AVG(attributable_pct) AS mean_attributable_pct,
    MAX(year) AS year
FROM deprivation_thirds
GROUP BY imd_third
ORDER BY imd_third;
