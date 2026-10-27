-- 01_borough_latest.sql
-- One row per London area (33 rows) with the latest value of each indicator.
-- "Latest" is the highest year_start each indicator has for London areas,
-- which differs between indicators (PM2.5 2024, asthma 2024/25, COPD 2023/24).
-- The City of London is kept but not ranked: its population is very small
-- (15,631 in mid-2025, against 145,734 in the next smallest area).

-- Latest year_start for each indicator, looking only at London areas
WITH latest_period AS (
    SELECT
        indicator_id,
        MAX(year_start) AS year_start
    FROM indicators
    WHERE area_code LIKE 'E09%'
    GROUP BY indicator_id
),

-- The indicator rows for those latest periods, for the five indicators we need
latest_values AS (
    SELECT
        i.area_code,
        i.indicator_id,
        i.year_start,
        i.period,
        i.value
    FROM indicators AS i
    INNER JOIN latest_period AS lp
        ON i.indicator_id = lp.indicator_id
        AND i.year_start = lp.year_start
    WHERE i.indicator_id IN (93867, 93861, 94240, 90810, 92302)
),

-- One column per indicator (conditional aggregation), one row per London area
borough_wide AS (
    SELECT
        a.area_code,
        a.area_name,
        a.is_city_of_london,
        MAX(CASE WHEN lv.indicator_id = 93867 THEN lv.value END)      AS pm25,
        MAX(CASE WHEN lv.indicator_id = 93867 THEN lv.year_start END) AS pm25_year,
        MAX(CASE WHEN lv.indicator_id = 93861 THEN lv.value END)      AS attributable_pct,
        MAX(CASE WHEN lv.indicator_id = 94240 THEN lv.value END)      AS imd_score,
        MAX(CASE WHEN lv.indicator_id = 90810 THEN lv.value END)      AS asthma_u19_rate,
        MAX(CASE WHEN lv.indicator_id = 90810 THEN lv.period END)     AS asthma_u19_period,
        MAX(CASE WHEN lv.indicator_id = 92302 THEN lv.value END)      AS copd_rate,
        MAX(CASE WHEN lv.indicator_id = 92302 THEN lv.period END)     AS copd_period
    FROM areas AS a
    INNER JOIN latest_values AS lv
        ON a.area_code = lv.area_code
    WHERE a.is_london
    GROUP BY a.area_code, a.area_name, a.is_city_of_london
),

-- PM2.5 rank among the 32 boroughs (1 = highest), City of London left out
pm25_ranks AS (
    SELECT
        area_code,
        RANK() OVER (ORDER BY pm25 DESC) AS pm25_rank
    FROM borough_wide
    WHERE NOT is_city_of_london
)

SELECT
    bw.area_code,
    bw.area_name,
    bw.pm25,
    bw.pm25_year,
    bw.attributable_pct,
    bw.imd_score,
    bw.asthma_u19_rate,
    bw.asthma_u19_period,
    bw.copd_rate,
    bw.copd_period,
    r.pm25_rank,
    bw.is_city_of_london
FROM borough_wide AS bw
LEFT JOIN pm25_ranks AS r
    ON bw.area_code = r.area_code
ORDER BY r.pm25_rank NULLS LAST;
