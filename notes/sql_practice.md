# SQL practice: 12 exercises on the London air database

> **Status, 27 October 2026:** An AI coding assistant wrote these exercises and their answers. Every answer was run against `data/london_air.duckdb` through R and DBI, and the expected results below are copied from those runs. A second agent then re-ran every query and checked the results and the other figures in the text against the database and the project's output files. If the database is rebuilt from newer Fingertips or ONS releases, some numbers may change.

Practice for live SQL tests in analyst interviews, using this project's own data. The exercises get harder as they go:

- 1 to 4: joins, filters, grouping and NULLs;
- 5 to 7: CTEs and window functions (`RANK`, `LAG`);
- 8 to 10: weighted averages, the mistakes that break them, and `NTILE`;
- 11 and 12: longer queries that combine all of the above.

All the questions come first. The answers, with SQL and expected results, are in a separate section at the bottom.

## How to use this sheet

- Read a question, write your query, run it, and check the row count before you check the values. Only then look at the answer.
- Run queries with the DuckDB command line (`duckdb -readonly data/london_air.duckdb`; set it up as in Option B of `notes/sql_tasks.md`), or from R in the project folder:

```r
con <- DBI::dbConnect(duckdb::duckdb(dbdir = "data/london_air.duckdb", read_only = TRUE, shared_home = FALSE))
DBI::dbGetQuery(con, paste(readLines("my_query.sql"), collapse = "\n"))
DBI::dbDisconnect(con, shutdown = TRUE)
```

- House style, as in `sql/`: one CTE per step with a comment above it, explicit `JOIN ... ON`, no `SELECT *` in the final output, and an `ORDER BY` at the end.
- The answers are DuckDB SQL, which is close to PostgreSQL. If the test uses another engine, watch for these differences:
  - SQL Server has no `LIMIT` (use `TOP 5`), no true boolean columns (write `is_london = 1`), and writes ordered `STRING_AGG` as `STRING_AGG(x, ', ') WITHIN GROUP (ORDER BY x)`.
  - SQL Server and PostgreSQL divide integers as integers, so `7 / 2` gives 3. In DuckDB `7 / 2` gives 3.5 (and `7 // 2` gives 3). Multiply by `100.0` or cast before dividing.
  - PostgreSQL's two-argument `ROUND` needs a `numeric`, so write `ROUND(x::numeric, 2)`.

## The tables

`notes/sql_tasks.md` lists every column of `indicators`, `areas` and `population`. In short:

| table | one row per | rows | what to know |
|---|---|---:|---|
| `indicators` | area, indicator and period | 3,108 | `value`, plus `lower_ci`, `upper_ci`, `count` and `denominator` where Fingertips publishes them, and `value_note`. `year_start` is the first calendar year of the period (2024 for '2024/25'). |
| `areas` | area | 35 | The 33 London areas (`is_london`; the City of London also has `is_city_of_london`), the London region (E12000007) and England (E92000001). |
| `population` | area, sex, single year of age and year | 48,048 | ONS mid-year estimates for the 33 London areas only, 2018 to 2025, ages 0 to 90 (90 means 90 and over): 182 rows per area and year. |
| `life_table` | sex and age | 202 | England, 2022 to 2024, ages 0 to 100 (`mx`, `qx`, `ex`). Not used below. |
| `utility_norms` | version, sex and age | 344 | EQ-5D-3L and EQ-5D-5L population norms, ages 16 to 101. Not used below. |

Indicators used below:

| indicator_id | what it is | periods |
|---|---|---|
| 93867 | annual mean PM2.5, µg/m³ | 2018 to 2024 |
| 93861 | % of deaths at ages 30+ attributable to PM2.5 | 2018 to 2024 |
| 90810 | asthma admissions under 19, crude rate per 100,000 | 2013/14 to 2024/25 |
| 92302 | emergency COPD admissions 35+, directly standardised rate per 100,000 | 2010/11 to 2023/24 |
| 94240 | IMD 2025 score (higher means more deprived) | 2025 |

Three quirks of the data that the exercises use or that could catch you out:

- **The City of London and Hackney.** For asthma and COPD admissions, Fingertips combines the City with Hackney. The City's row exists, but its `value`, `count` and `denominator` are NULL; Hackney's figures cover both areas (decision D2 in `notes/decision_log.md`).
- **Published, not summed, totals.** The London region and England rows in `indicators` are figures as Fingertips publishes them. The region has PM2.5 rows (93867 and 93861) but no admissions rows.
- **`year_start` is not always unique.** For all-cause mortality (93823), each `year_start` from 2001 to 2023 has two periods, a single year ('2019') and a three-year one ('2019 - 21'). For that indicator, filter on `period` too.

---

## Questions

### 1. Warm-up: the five highest boroughs in 2024

List the five London boroughs with the highest annual mean PM2.5 in 2024, highest first, with the values rounded to two decimal places. Leave out the City of London: the project keeps it in every table but leaves it out of rankings, because its very small population makes its figures unstable and its PM2.5 (10.96 µg/m³ in 2024) would top this ranking (decision D2).

- **Tables:** `indicators`, `areas`.
- **Hint:** PM2.5 is `indicator_id = 93867`, and the year is in `year_start`. Join to `areas` and use the `is_city_of_london` flag rather than typing the City's area code.

### 2. Inner versus left join: who is missing, and why?

(a) List every area in `areas` (all 35) with its asthma admissions rate for under-19s in 2024/25 (indicator 90810, `year_start` 2024). Add a column `missing_reason` that says 'No row in indicators' when the area has no matching row at all, and 'Row present, value blank' when the row exists but its value is NULL. Show the `value_note` too. (b) How many rows do you get if you use `INNER JOIN` instead, and which area drops out? Why does the City of London not drop out? (c) A colleague wrote the query below to keep all 35 areas. How many rows does it return, and why? Fix it.

```sql
SELECT
    a.area_code,
    a.area_name,
    i.value AS asthma_rate
FROM areas AS a
LEFT JOIN indicators AS i
    ON a.area_code = i.area_code
WHERE i.indicator_id = 90810
    AND i.year_start = 2024
ORDER BY a.area_code;
```

- **Tables:** `areas`, `indicators`.
- **Hint:** after a `LEFT JOIN`, a NULL in the right-hand table's join key means "no match", while a NULL `value` next to a non-NULL key means "matched, but blank". For (c), the join is on `area_code` alone, so think about which rows each area meets, when `WHERE` runs, and what is left for an area whose rows are all for other indicators.

### 3. WHERE versus HAVING

England's legal target for PM2.5 is an annual mean of 10 µg/m³ by the end of 2040 (SI 2023/96, reg. 4; see `notes/verified_sources.md`). The target is assessed at every relevant monitoring station (reg. 5), not on an area average, so comparing borough means with it is only a rough guide. For each borough (City excluded), count the years from 2018 to 2024 in which its annual mean PM2.5 was above 10, list those years in one text column, and keep only the boroughs with four or more such years.

- **Tables:** `indicators`, `areas`.
- **Hint:** there are two filters at two levels: one on single rows (a borough-year above 10) and one on groups (a borough with at least four such rows). One belongs in `WHERE`, the other in `HAVING`. `STRING_AGG(text, ', ' ORDER BY ...)` builds the list.

### 4. Handling NULLs

In 2020/21, two London areas have no published asthma admissions rate. (a) In a single row, report for the 33 London areas: the number of rows; the number of non-NULL values; how many rows `value = NULL` finds and how many `value IS NULL` finds; the mean of the published rates; and the mean you would get if the gaps were treated as zero. (b) List the areas with no value, showing 'not published' instead of NULL for the rate, and the `value_note` as the reason.

- **Tables:** `indicators`, `areas`.
- **Hint:** `COUNT(*)` counts rows; `COUNT(column)` counts non-NULL values. `AVG` skips NULLs. `NULL = NULL` is not true but unknown (NULL). `COALESCE` swaps a NULL for a value you choose, but the arguments must share a type: `COALESCE(value, 'not published')` fails in DuckDB with a conversion error as soon as it meets a NULL, because it tries to turn the text into a number. Cast the number to text first.

### 5. CTEs: boroughs above England on both admissions measures

Using the latest period available for each indicator, find the boroughs (City excluded) whose rates are significantly higher than England's for both asthma admissions under 19 (90810) and emergency COPD admissions 35+ (92302). Here "significantly higher" means the borough's lower 95% confidence limit (`lower_ci`) is above England's value; label each borough 'Higher', 'Similar' or 'Lower' on each measure. Show the period and the rate for each measure. Do not type the years into the query: the latest period differs between the two indicators, so let the query find it.

- **Tables:** `indicators`, `areas`.
- **Hint:** one CTE per step: latest `year_start` per indicator; every area's row for that period; England's value; each borough labelled against England; one row per borough (conditional aggregation, `MAX(CASE WHEN indicator_id = ... THEN ... END)`); then filter.

### 6. RANK: the highest and lowest borough each year

For each year from 2018 to 2024, name the borough with the highest PM2.5 and the borough with the lowest (City excluded), with their values. Add a check column showing how many boroughs share first place, so that a tie would not go unnoticed.

- **Tables:** `indicators`, `areas`.
- **Hint:** `RANK() OVER (PARTITION BY year ORDER BY pm25 DESC)` restarts the ranking every year. Rank once in each direction, then pick out rank 1 with conditional aggregation. Be ready to explain how `RANK`, `DENSE_RANK` and `ROW_NUMBER` differ when there are ties.

### 7. LAG: year-on-year change by borough

(a) For each borough (City excluded) and year, show PM2.5, the previous year's value and the change, rounded to two decimals. (b) Summarise by year from 2019 to 2024: the number of boroughs, how many rose, how many fell, the mean change, and the smallest and largest change. In which years did PM2.5 rise in every borough?

- **Tables:** `indicators`, `areas`.
- **Hint:** `LAG(pm25) OVER (PARTITION BY area_name ORDER BY year)`. Without `PARTITION BY`, the first year of one borough would be compared with the last year of the one before it. The 2018 rows have no previous year, so their change is NULL: drop them before you summarise.

### 8. A population-weighted average

Calculate London's PM2.5 for each year from 2018 to 2024 in two ways from the 33 areas: a simple mean, and a mean weighted by each area's total population in the same year. Compare both with the official Fingertips figure for the London region (`area_code = 'E12000007'`), showing the differences to three decimal places. Which method comes closer?

- **Tables:** `indicators`, `areas`, `population`.
- **Hint:** a weighted mean is `SUM(value * population) / SUM(population)`. The population table has 182 rows per area and year (two sexes, ages 0 to 90), so sum it to one row per area and year in its own CTE before you join. Join on both area and year, so that 2018 values are weighted by 2018 population.

### 9. A common mistake, wrong next to right

Your manager asks for London's rate of asthma admissions under 19, per 100,000, for 2024/25. Calculate it four ways, in one table with one row per method, and explain why two of them are wrong:

1. a plain average of the borough rates;
2. total admissions divided by the total of Fingertips' own denominators;
3. a colleague's version, which joins the asthma rows to the `population` table (ages 0 to 18, mid-2024) and then sums both sides;
4. the same ONS denominator as method 3, but with the population summed to one row per area before the join.

Show the number of rows each method uses, the admissions and population totals, and the rate to one decimal place.

- **Tables:** `indicators`, `areas`, `population`.
- **Hint:** check the row count of every join. If a join returns more rows than the table you started from, anything you `SUM` from that table is multiplied. The City of London's admissions count is blank because it is combined with Hackney's, but its children still belong in the London denominator. Stack the four methods with `UNION ALL`, with a step number to sort by.

### 10. NTILE: deprivation quarters

Split the 32 boroughs (City excluded) into four equal groups by IMD 2025 score (indicator 94240), with quarter 1 the least deprived. For each quarter, report the number of boroughs, the lowest and highest IMD score, PM2.5 in 2024 weighted by mid-2024 population, and the pooled asthma admissions rate for 2024/25 (total admissions over total denominator). Does PM2.5 rise with deprivation? Does the asthma rate?

- **Tables:** `indicators`, `areas`, `population`.
- **Hint:** `NTILE(4) OVER (ORDER BY imd_score)` deals the rows into four groups as equal in size as possible; with 32 boroughs, each gets 8. Pivot the three indicators to one row per borough first, then use the methods from Exercises 8 and 9 for the averages. This compares areas, not people (an ecological comparison).

### 11. Harder: the share of London's population aged 30 and over

The model applies the PM2.5 effect to residents aged 30 and over in mid-2025. For each of the 33 areas, show the total population, the population aged 30+, the share aged 30+ within the area, the area's share of London's total population and of London's population aged 30+, and the difference between those two shares in percentage points. Order by the share aged 30+ within the area, highest first. Which areas are oldest and youngest on this measure, and how does that fit with the range of per-resident break-even figures in the README?

- **Tables:** `population`, `areas`.
- **Hint:** a conditional sum, `SUM(CASE WHEN age >= 30 THEN population ELSE 0 END)`, gives both totals in one pass. A window function with an empty `OVER ()` puts London's total on every row without a second query. Multiply by `100.0`, not `100`, so that engines which divide integers as integers do not round your shares to zero.

### 12. Harder: which borough's PM2.5 fell most between 2018 and 2024?

For each borough (City excluded), show PM2.5 in 2018 and 2024, the absolute fall and the percentage fall, the borough's rank on each, and how its absolute fall compares with London's population-weighted fall (each year weighted by its own population). Order by the absolute fall. Does the ranking change if you use the percentage fall? Where does Tower Hamlets, the highest borough in 2024, come?

- **Tables:** `indicators`, `areas`, `population`.
- **Hint:** conditional aggregation puts 2018 and 2024 side by side. `RANK()` with no `PARTITION BY` ranks across all boroughs. London's fall is a single number: work it out in its own CTE and attach it to every row with a `CROSS JOIN`.

---

## Answers

### Answer 1

```sql
-- The 2024 PM2.5 value for each London borough, City of London left out
WITH borough_pm25_2024 AS (
    SELECT
        i.area_name,
        i.value AS pm25
    FROM indicators AS i
    INNER JOIN areas AS a
        ON i.area_code = a.area_code
    WHERE i.indicator_id = 93867      -- annual mean PM2.5
        AND i.year_start = 2024
        AND a.is_london
        AND NOT a.is_city_of_london
)

SELECT
    area_name,
    ROUND(pm25, 2) AS pm25_2024
FROM borough_pm25_2024
ORDER BY pm25 DESC
LIMIT 5;
```

**Expected result:** 5 rows.

| area_name | pm25_2024 |
|---|---:|
| Tower Hamlets | 9.81 |
| Westminster | 9.71 |
| Islington | 9.69 |
| Hackney | 9.65 |
| Newham | 9.64 |

`LIMIT` cuts at exactly five rows even if the fifth and sixth were tied; here they are not (Camden is sixth with 9.55, and `sql/01_borough_latest.sql` gives the same order).

### Answer 2

(a) Every area, with the reason for any gap:

```sql
-- Asthma admissions under 19 (90810) in 2024/25, for every area that has a row
WITH asthma_2024 AS (
    SELECT
        area_code,
        value,
        value_note
    FROM indicators
    WHERE indicator_id = 90810
        AND year_start = 2024
)

-- Every area in areas, matched or not, with the reason for any gap
SELECT
    a.area_code,
    a.area_name,
    a.area_type,
    ROUND(ast.value, 2) AS asthma_rate,
    CASE
        WHEN ast.area_code IS NULL THEN 'No row in indicators'
        WHEN ast.value IS NULL THEN 'Row present, value blank'
    END AS missing_reason,
    ast.value_note
FROM areas AS a
LEFT JOIN asthma_2024 AS ast
    ON a.area_code = ast.area_code
ORDER BY missing_reason NULLS LAST, a.area_code;
```

**Expected result:** 35 rows. The first four:

| area_code | area_name | area_type | asthma_rate | missing_reason | value_note |
|---|---|---|---:|---|---|
| E12000007 | London region (statistical) | Region | NULL | No row in indicators | NULL |
| E09000001 | City of London | Local authority | NULL | Row present, value blank | Value for Hackney and City of London combined |
| E09000002 | Barking and Dagenham | Local authority | 322.1 | NULL | NULL |
| E09000003 | Barnet | Local authority | 96.13 | NULL | NULL |

(b) Change `LEFT JOIN` to `INNER JOIN` in the query above and you get **34 rows**. The London region drops out, because it has no asthma row at all. The City of London stays, with a NULL rate, because its row exists: an inner join only needs the keys to match, not the value to be filled in. So "missing" can mean two different things, and only a `LEFT JOIN` with a check on the key shows both.

(c) The colleague's query returns **34 rows**, the same as an inner join. The join is on `area_code` alone, so each area first meets every one of its rows in `indicators`. `WHERE` runs after the join and keeps only the rows for indicator 90810 in 2024. The London region's only matches are its 14 PM2.5 rows (indicators 93867 and 93861), so all of them are filtered out and the region disappears. An area with no rows in `indicators` at all would go too: its `i.indicator_id` would be NULL, and `NULL = 90810` is unknown rather than true. Either way, a `WHERE` condition on the right-hand table turns a `LEFT JOIN` into an inner join. Conditions on the right-hand table of a `LEFT JOIN` belong in `ON`:

```sql
-- Filters on the right-hand table go in ON, so unmatched areas survive
SELECT
    a.area_code,
    a.area_name,
    i.value AS asthma_rate
FROM areas AS a
LEFT JOIN indicators AS i
    ON a.area_code = i.area_code
    AND i.indicator_id = 90810
    AND i.year_start = 2024
ORDER BY a.area_code;
```

This returns **35 rows**, with NULL for the London region and the City of London.

### Answer 3

```sql
-- One row per borough and year of PM2.5, City of London left out
WITH borough_pm25 AS (
    SELECT
        i.area_name,
        i.year_start AS year,
        i.value AS pm25
    FROM indicators AS i
    INNER JOIN areas AS a
        ON i.area_code = a.area_code
    WHERE i.indicator_id = 93867
        AND a.is_london
        AND NOT a.is_city_of_london
)

SELECT
    area_name,
    COUNT(*) AS years_above_10,
    STRING_AGG(CAST(year AS VARCHAR), ', ' ORDER BY year) AS which_years
FROM borough_pm25
WHERE pm25 > 10          -- row filter: keeps only borough-years above 10
GROUP BY area_name
HAVING COUNT(*) >= 4     -- group filter: keeps boroughs with 4 or more such years
ORDER BY area_name;
```

**Expected result:** 7 rows.

| area_name | years_above_10 | which_years |
|---|---:|---|
| Hackney | 4 | 2018, 2019, 2020, 2022 |
| Islington | 4 | 2018, 2019, 2020, 2022 |
| Kensington and Chelsea | 4 | 2018, 2019, 2020, 2022 |
| Newham | 4 | 2018, 2019, 2020, 2022 |
| Southwark | 4 | 2018, 2019, 2020, 2022 |
| Tower Hamlets | 4 | 2018, 2019, 2020, 2022 |
| Westminster | 4 | 2018, 2019, 2020, 2022 |

Without the `HAVING` line the query returns all 32 boroughs: 22 with two years above 10, 3 with three (Camden, Lambeth and Lewisham) and these 7 with four. Every borough was above 10 in 2018 and 2019, and none was in 2021, 2023 or 2024 (see Answer 6). If you move the count into `WHERE` (`... AND COUNT(*) >= 4`), DuckDB refuses: "Binder Error: WHERE clause cannot contain aggregates!". `WHERE` filters rows before grouping; `HAVING` filters groups after it.

### Answer 4

(a) The summary row:

```sql
-- Asthma admissions under 19 in 2020/21 for the 33 London areas
WITH asthma_2020 AS (
    SELECT
        i.area_name,
        i.value,
        i.value_note
    FROM indicators AS i
    INNER JOIN areas AS a
        ON i.area_code = a.area_code
    WHERE i.indicator_id = 90810
        AND i.year_start = 2020
        AND a.is_london
)

SELECT
    COUNT(*)                                          AS n_rows,
    COUNT(value)                                      AS n_values,          -- COUNT(column) skips NULLs
    SUM(CASE WHEN value = NULL THEN 1 ELSE 0 END)     AS n_equals_null,     -- wrong test: never true
    SUM(CASE WHEN value IS NULL THEN 1 ELSE 0 END)    AS n_is_null,         -- right test
    ROUND(AVG(value), 2)                              AS mean_of_published, -- AVG skips NULLs
    ROUND(AVG(COALESCE(value, 0)), 2)                 AS mean_nulls_as_zero -- wrong: treats gaps as 0
FROM asthma_2020;
```

**Expected result:** 1 row.

| n_rows | n_values | n_equals_null | n_is_null | mean_of_published | mean_nulls_as_zero |
|---:|---:|---:|---:|---:|---:|
| 33 | 31 | 0 | 2 | 77.86 | 73.15 |

`value = NULL` finds nothing, even though two values are NULL. Treating the gaps as zero pulls the mean down from 77.86 to 73.15, which would be wrong: a missing rate is unknown, not zero. (Both means are plain averages of rates, used here only to show how NULLs behave; Answer 9 shows why a pooled rate is better.)

(b) The gaps, labelled:

```sql
-- Asthma admissions under 19 in 2020/21 for the 33 London areas
WITH asthma_2020 AS (
    SELECT
        i.area_name,
        i.value,
        i.value_note
    FROM indicators AS i
    INNER JOIN areas AS a
        ON i.area_code = a.area_code
    WHERE i.indicator_id = 90810
        AND i.year_start = 2020
        AND a.is_london
)

-- The areas with no published value, with readable labels instead of NULL
SELECT
    area_name,
    COALESCE(CAST(ROUND(value, 2) AS VARCHAR), 'not published') AS asthma_rate,
    COALESCE(value_note, 'no note')                             AS reason
FROM asthma_2020
WHERE value IS NULL
ORDER BY area_name;
```

**Expected result:** 2 rows.

| area_name | asthma_rate | reason |
|---|---|---|
| City of London | not published | Value for Hackney and City of London combined |
| Kensington and Chelsea | not published | Value suppressed for disclosure control due to small count |

The two gaps have different causes: the City's admissions are counted in Hackney's figure, while Kensington and Chelsea's value was withheld because the count was small.

### Answer 5

```sql
-- 1. Latest year_start for each admissions indicator
WITH latest_period AS (
    SELECT
        indicator_id,
        MAX(year_start) AS year_start
    FROM indicators
    WHERE indicator_id IN (90810, 92302)   -- asthma under 19, COPD 35+
    GROUP BY indicator_id
),

-- 2. Every area's row for that latest period
latest_values AS (
    SELECT
        i.area_code,
        i.area_name,
        i.indicator_id,
        i.period,
        i.value,
        i.lower_ci,
        i.upper_ci
    FROM indicators AS i
    INNER JOIN latest_period AS lp
        ON i.indicator_id = lp.indicator_id
        AND i.year_start = lp.year_start
),

-- 3. England's value for each indicator
england AS (
    SELECT
        indicator_id,
        value AS england_value
    FROM latest_values
    WHERE area_code = 'E92000001'
),

-- 4. The 32 boroughs, each compared with England using its 95% interval
compared AS (
    SELECT
        lv.area_name,
        lv.indicator_id,
        lv.period,
        lv.value,
        e.england_value,
        CASE
            WHEN lv.lower_ci > e.england_value THEN 'Higher'
            WHEN lv.upper_ci < e.england_value THEN 'Lower'
            ELSE 'Similar'
        END AS vs_england
    FROM latest_values AS lv
    INNER JOIN areas AS a
        ON lv.area_code = a.area_code
    INNER JOIN england AS e
        ON lv.indicator_id = e.indicator_id
    WHERE a.is_london
        AND NOT a.is_city_of_london
),

-- 5. One row per borough: asthma and COPD side by side
borough_wide AS (
    SELECT
        area_name,
        MAX(CASE WHEN indicator_id = 90810 THEN period END)     AS asthma_period,
        MAX(CASE WHEN indicator_id = 90810 THEN value END)      AS asthma_rate,
        MAX(CASE WHEN indicator_id = 90810 THEN vs_england END) AS asthma_vs_england,
        MAX(CASE WHEN indicator_id = 92302 THEN period END)     AS copd_period,
        MAX(CASE WHEN indicator_id = 92302 THEN value END)      AS copd_rate,
        MAX(CASE WHEN indicator_id = 92302 THEN vs_england END) AS copd_vs_england
    FROM compared
    GROUP BY area_name
)

SELECT
    area_name,
    asthma_period,
    ROUND(asthma_rate, 1) AS asthma_rate,
    asthma_vs_england,
    copd_period,
    ROUND(copd_rate, 1)   AS copd_rate,
    copd_vs_england
FROM borough_wide
WHERE asthma_vs_england = 'Higher'
    AND copd_vs_england = 'Higher'
ORDER BY asthma_rate DESC;
```

**Expected result:** 2 rows.

| area_name | asthma_period | asthma_rate | asthma_vs_england | copd_period | copd_rate | copd_vs_england |
|---|---|---:|---|---|---:|---|
| Barking and Dagenham | 2024/25 | 322.1 | Higher | 2023/24 | 697.4 | Higher |
| Hillingdon | 2024/25 | 194.6 | Higher | 2023/24 | 398.8 | Higher |

England's values in those periods are 138.8 (asthma) and 356.8 (COPD). On asthma alone, 9 boroughs are higher than England, 16 similar and 7 lower; on COPD, 5 are higher, 8 similar and 19 lower. Brent has the highest asthma rate (333.8) but drops out because its COPD rate is significantly lower than England's (277.9). Comparing a confidence limit with England's value is a simplification: it ignores England's own (very narrow) interval.

### Answer 6

```sql
-- One row per borough and year of PM2.5, City of London left out
WITH borough_pm25 AS (
    SELECT
        i.area_name,
        i.year_start AS year,
        i.value AS pm25
    FROM indicators AS i
    INNER JOIN areas AS a
        ON i.area_code = a.area_code
    WHERE i.indicator_id = 93867
        AND a.is_london
        AND NOT a.is_city_of_london
),

-- Rank within each year, from the top and from the bottom
ranked AS (
    SELECT
        area_name,
        year,
        pm25,
        RANK() OVER (PARTITION BY year ORDER BY pm25 DESC) AS rank_highest,
        RANK() OVER (PARTITION BY year ORDER BY pm25 ASC)  AS rank_lowest
    FROM borough_pm25
)

-- Pick rank 1 from each end, one row per year
SELECT
    year,
    MAX(CASE WHEN rank_highest = 1 THEN area_name END)      AS highest_borough,
    ROUND(MAX(CASE WHEN rank_highest = 1 THEN pm25 END), 2) AS highest_pm25,
    MAX(CASE WHEN rank_lowest = 1 THEN area_name END)       AS lowest_borough,
    ROUND(MAX(CASE WHEN rank_lowest = 1 THEN pm25 END), 2)  AS lowest_pm25,
    SUM(CASE WHEN rank_highest = 1 THEN 1 ELSE 0 END)       AS n_tied_top    -- tie check
FROM ranked
GROUP BY year
ORDER BY year;
```

**Expected result:** 7 rows.

| year | highest_borough | highest_pm25 | lowest_borough | lowest_pm25 | n_tied_top |
|---:|---|---:|---|---:|---:|
| 2018 | Newham | 13.49 | Bromley | 10.96 | 1 |
| 2019 | Newham | 12.99 | Bromley | 10.56 | 1 |
| 2020 | Newham | 10.62 | Hillingdon | 8.62 | 1 |
| 2021 | Westminster | 9.52 | Bromley | 7.67 | 1 |
| 2022 | Islington | 10.69 | Bromley | 8.26 | 1 |
| 2023 | Tower Hamlets | 9.23 | Bromley | 7.54 | 1 |
| 2024 | Tower Hamlets | 9.81 | Bromley | 8.13 | 1 |

No ties. With a tie, `RANK` would give both boroughs rank 1 (and skip rank 2), `DENSE_RANK` would also give both rank 1 (but not skip), and `ROW_NUMBER` would pick one of them arbitrarily. `MAX(CASE ...)` would then hide one of the tied boroughs, which is why the check column is there. The top spot moves from Newham to Westminster, Islington and then Tower Hamlets, while Bromley is lowest in every year except 2020.

### Answer 7

(a) Change by borough and year:

```sql
-- One row per borough and year of PM2.5, City of London left out
WITH borough_pm25 AS (
    SELECT
        i.area_name,
        i.year_start AS year,
        i.value AS pm25
    FROM indicators AS i
    INNER JOIN areas AS a
        ON i.area_code = a.area_code
    WHERE i.indicator_id = 93867
        AND a.is_london
        AND NOT a.is_city_of_london
),

-- Previous year's value within the same borough
with_previous AS (
    SELECT
        area_name,
        year,
        pm25,
        LAG(pm25) OVER (PARTITION BY area_name ORDER BY year) AS pm25_previous
    FROM borough_pm25
)

SELECT
    area_name,
    year,
    ROUND(pm25, 2)                 AS pm25,
    ROUND(pm25_previous, 2)        AS pm25_previous,
    ROUND(pm25 - pm25_previous, 2) AS change     -- NULL in 2018: no previous year
FROM with_previous
ORDER BY area_name, year;
```

**Expected result:** 224 rows (32 boroughs × 7 years). The first seven:

| area_name | year | pm25 | pm25_previous | change |
|---|---:|---:|---:|---:|
| Barking and Dagenham | 2018 | 13.04 | NULL | NULL |
| Barking and Dagenham | 2019 | 12.64 | 13.04 | -0.40 |
| Barking and Dagenham | 2020 | 10.00 | 12.64 | -2.64 |
| Barking and Dagenham | 2021 | 8.59 | 10.00 | -1.41 |
| Barking and Dagenham | 2022 | 9.49 | 8.59 | 0.90 |
| Barking and Dagenham | 2023 | 8.33 | 9.49 | -1.16 |
| Barking and Dagenham | 2024 | 9.13 | 8.33 | 0.80 |

(b) Summary by year:

```sql
-- One row per borough and year of PM2.5, City of London left out
WITH borough_pm25 AS (
    SELECT
        i.area_name,
        i.year_start AS year,
        i.value AS pm25
    FROM indicators AS i
    INNER JOIN areas AS a
        ON i.area_code = a.area_code
    WHERE i.indicator_id = 93867
        AND a.is_london
        AND NOT a.is_city_of_london
),

-- Year-on-year change within each borough
changes AS (
    SELECT
        area_name,
        year,
        pm25 - LAG(pm25) OVER (PARTITION BY area_name ORDER BY year) AS change
    FROM borough_pm25
)

-- Summarise by year; WHERE drops 2018, which has no previous year
SELECT
    year,
    COUNT(*)                                     AS n_boroughs,
    SUM(CASE WHEN change > 0 THEN 1 ELSE 0 END)  AS n_rose,
    SUM(CASE WHEN change < 0 THEN 1 ELSE 0 END)  AS n_fell,
    ROUND(AVG(change), 2)                        AS mean_change,
    ROUND(MIN(change), 2)                        AS min_change,
    ROUND(MAX(change), 2)                        AS max_change
FROM changes
WHERE change IS NOT NULL
GROUP BY year
ORDER BY year;
```

**Expected result:** 6 rows.

| year | n_boroughs | n_rose | n_fell | mean_change | min_change | max_change |
|---:|---:|---:|---:|---:|---:|---:|
| 2019 | 32 | 1 | 31 | -0.34 | -0.61 | 0.01 |
| 2020 | 32 | 0 | 32 | -2.35 | -2.84 | -1.70 |
| 2021 | 32 | 0 | 32 | -0.88 | -1.47 | -0.30 |
| 2022 | 32 | 32 | 0 | 0.93 | 0.59 | 1.27 |
| 2023 | 32 | 0 | 32 | -1.33 | -1.63 | -0.72 |
| 2024 | 32 | 32 | 0 | 0.60 | 0.38 | 0.83 |

PM2.5 rose in every borough in 2022 and in 2024. The one rise in 2019 was Harrow, by 0.006 µg/m³. The largest single-year fall was Barnet's in 2020 (2.84) and the largest rise was Islington's in 2022 (1.27). `WHERE` runs before window functions. If you put `WHERE year >= 2019` in the same query as the `LAG`, the 2018 rows are gone before `LAG` sees them, and every 2019 change comes out NULL. So work the change out in a CTE and filter afterwards.

### Answer 8

```sql
-- 1. PM2.5 for the 33 London areas, 2018 to 2024
WITH area_pm25 AS (
    SELECT
        i.area_code,
        i.year_start AS year,
        i.value AS pm25
    FROM indicators AS i
    INNER JOIN areas AS a
        ON i.area_code = a.area_code
    WHERE i.indicator_id = 93867
        AND a.is_london
),

-- 2. Population per area and year, summed over sex and age BEFORE the join
area_population AS (
    SELECT
        area_code,
        year,
        SUM(population) AS population
    FROM population
    GROUP BY area_code, year
),

-- 3. London two ways: simple mean and population-weighted mean
london AS (
    SELECT
        ap.year,
        AVG(ap.pm25)                                       AS simple_mean,
        SUM(ap.pm25 * pop.population) / SUM(pop.population) AS weighted_mean
    FROM area_pm25 AS ap
    INNER JOIN area_population AS pop
        ON ap.area_code = pop.area_code
        AND ap.year = pop.year           -- 2018 values weighted by 2018 population
    GROUP BY ap.year
),

-- 4. The official Fingertips figure for the London region
official AS (
    SELECT
        year_start AS year,
        value AS fingertips_london
    FROM indicators
    WHERE indicator_id = 93867
        AND area_code = 'E12000007'
)

SELECT
    l.year,
    ROUND(l.simple_mean, 3)                         AS simple_mean,
    ROUND(l.weighted_mean, 3)                       AS weighted_mean,
    ROUND(o.fingertips_london, 3)                   AS fingertips_london,
    ROUND(l.simple_mean - o.fingertips_london, 3)   AS simple_minus_official,
    ROUND(l.weighted_mean - o.fingertips_london, 3) AS weighted_minus_official
FROM london AS l
INNER JOIN official AS o
    ON l.year = o.year
ORDER BY l.year;
```

**Expected result:** 7 rows.

| year | simple_mean | weighted_mean | fingertips_london | simple_minus_official | weighted_minus_official |
|---:|---:|---:|---:|---:|---:|
| 2018 | 12.295 | 12.254 | 12.260 | 0.035 | -0.006 |
| 2019 | 11.959 | 11.924 | 11.933 | 0.026 | -0.009 |
| 2020 | 9.601 | 9.567 | 9.576 | 0.025 | -0.009 |
| 2021 | 8.732 | 8.682 | 8.699 | 0.033 | -0.017 |
| 2022 | 9.677 | 9.620 | 9.613 | 0.064 | 0.007 |
| 2023 | 8.352 | 8.296 | 8.293 | 0.060 | 0.003 |
| 2024 | 8.968 | 8.898 | 8.895 | 0.073 | 0.003 |

The weighted mean is within 0.017 µg/m³ of the official figure every year; the simple mean is above it every year, by up to 0.073. A simple mean gives every area the same weight, so the City of London (15,497 residents in mid-2024) counts as much as Croydon (408,636). The weighted mean is the same as the London rows of `sql/02_trends.sql`.

### Answer 9

```sql
-- 1. Asthma admissions under 19 in 2024/25 for the 33 London areas.
--    The City of London's count is blank: its admissions sit in Hackney's row.
WITH asthma AS (
    SELECT
        i.area_code,
        i.value       AS rate,
        i.count       AS admissions,
        i.denominator AS fingertips_population
    FROM indicators AS i
    INNER JOIN areas AS a
        ON i.area_code = a.area_code
    WHERE i.indicator_id = 90810
        AND i.year_start = 2024
        AND a.is_london
),

-- 2. ONS population aged 0 to 18 in mid-2024, summed to one row per area
pop_0_18 AS (
    SELECT
        area_code,
        SUM(population) AS population
    FROM population
    WHERE year = 2024
        AND age <= 18
    GROUP BY area_code
),

-- WRONG A: a plain average of the borough rates
avg_of_rates AS (
    SELECT
        1                                 AS step,
        'Wrong: average of borough rates' AS method,
        COUNT(rate)                       AS n_rows,
        CAST(NULL AS DOUBLE)              AS admissions,
        CAST(NULL AS DOUBLE)              AS population,
        AVG(rate)                         AS rate_per_100k
    FROM asthma
),

-- RIGHT A: pool the counts and the denominators, then divide
pooled AS (
    SELECT
        2                                                       AS step,
        'Right: total admissions / total Fingertips population' AS method,
        COUNT(admissions)                                       AS n_rows,
        SUM(admissions)                                         AS admissions,
        SUM(fingertips_population)                              AS population,
        100000.0 * SUM(admissions) / SUM(fingertips_population) AS rate_per_100k
    FROM asthma
),

-- WRONG B: join to the population table at age level, then sum.
--          Each asthma row now appears 38 times (19 ages x 2 sexes).
fan_out AS (
    SELECT
        3                                                   AS step,
        'Wrong: join ONS population at age level, then sum' AS method,
        COUNT(*)                                            AS n_rows,
        SUM(ast.admissions)                                 AS admissions,
        SUM(p.population)                                   AS population,
        100000.0 * SUM(ast.admissions) / SUM(p.population)  AS rate_per_100k
    FROM asthma AS ast
    INNER JOIN population AS p
        ON ast.area_code = p.area_code
    WHERE p.year = 2024
        AND p.age <= 18
),

-- RIGHT B: sum the population to area level first, then join one to one
aggregated_first AS (
    SELECT
        4                                                    AS step,
        'Right: sum ONS population to area first, then join' AS method,
        COUNT(*)                                             AS n_rows,
        SUM(ast.admissions)                                  AS admissions,
        SUM(pop.population)                                  AS population,
        100000.0 * SUM(ast.admissions) / SUM(pop.population) AS rate_per_100k
    FROM asthma AS ast
    INNER JOIN pop_0_18 AS pop
        ON ast.area_code = pop.area_code
)

SELECT step, method, n_rows, admissions, population, ROUND(rate_per_100k, 1) AS rate_per_100k FROM avg_of_rates
UNION ALL
SELECT step, method, n_rows, admissions, population, ROUND(rate_per_100k, 1) AS rate_per_100k FROM pooled
UNION ALL
SELECT step, method, n_rows, admissions, population, ROUND(rate_per_100k, 1) AS rate_per_100k FROM fan_out
UNION ALL
SELECT step, method, n_rows, admissions, population, ROUND(rate_per_100k, 1) AS rate_per_100k FROM aggregated_first
ORDER BY step;
```

**Expected result:** 4 rows.

| step | method | n_rows | admissions | population | rate_per_100k |
|---:|---|---:|---:|---:|---:|
| 1 | Wrong: average of borough rates | 32 | NULL | NULL | 163.9 |
| 2 | Right: total admissions / total Fingertips population | 32 | 3330 | 2021896 | 164.7 |
| 3 | Wrong: join ONS population at age level, then sum | 1254 | 126540 | 1975758 | 6404.6 |
| 4 | Right: sum ONS population to area first, then join | 33 | 3330 | 1975758 | 168.5 |

- **Method 3 is the fan-out mistake.** Each of the 33 asthma rows meets 38 population rows (19 ages × 2 sexes), giving 1,254 rows. The population total is still right, but every admissions count is added 38 times (126,540 = 3,330 × 38), so the rate is 38 times too high. The row count gives it away. Summing the population to one row per area first (method 4) makes the join one to one.
- **Method 1 averages rates.** Here the gap is small (163.9 against 164.7), but the method is still wrong: it gives Kensington and Chelsea (denominator 23,924) the same weight as Barnet (98,823). A rate for a group is total events over total population.
- **The two right answers differ** (164.7 and 168.5) because Fingertips' denominators add up to more than the ONS mid-2024 population aged 0 to 18 in this database (2,021,896 against 1,975,758). Method 2 matches the way Fingertips calculates each borough's rate (Hackney: 115 / 58,218 × 100,000 = 197.5), so use it for a figure to be compared with Fingertips.

### Answer 10

```sql
-- 1. One row per borough: IMD 2025 score, 2024 PM2.5, 2024/25 asthma count and denominator
WITH borough_values AS (
    SELECT
        a.area_code,
        a.area_name,
        MAX(CASE WHEN i.indicator_id = 94240 THEN i.value END)                         AS imd_score,
        MAX(CASE WHEN i.indicator_id = 93867 AND i.year_start = 2024 THEN i.value END) AS pm25,
        MAX(CASE WHEN i.indicator_id = 90810 AND i.year_start = 2024 THEN i.count END) AS asthma_admissions,
        MAX(CASE WHEN i.indicator_id = 90810 AND i.year_start = 2024 THEN i.denominator END) AS asthma_population
    FROM areas AS a
    INNER JOIN indicators AS i
        ON a.area_code = i.area_code
    WHERE a.is_london
        AND NOT a.is_city_of_london
        AND i.indicator_id IN (94240, 93867, 90810)
    GROUP BY a.area_code, a.area_name
),

-- 2. Total population in mid-2024, one row per area (summed before joining)
population_2024 AS (
    SELECT
        area_code,
        SUM(population) AS population
    FROM population
    WHERE year = 2024
    GROUP BY area_code
),

-- 3. Deprivation quarters: NTILE(4) on ascending IMD score, so 4 = most deprived
quartered AS (
    SELECT
        bv.area_name,
        bv.imd_score,
        bv.pm25,
        bv.asthma_admissions,
        bv.asthma_population,
        p.population,
        NTILE(4) OVER (ORDER BY bv.imd_score) AS imd_quarter
    FROM borough_values AS bv
    INNER JOIN population_2024 AS p
        ON bv.area_code = p.area_code
)

SELECT
    imd_quarter,
    COUNT(*)                                                       AS n_boroughs,
    ROUND(MIN(imd_score), 1)                                       AS imd_min,
    ROUND(MAX(imd_score), 1)                                       AS imd_max,
    ROUND(SUM(pm25 * population) / SUM(population), 2)             AS pm25_weighted,
    ROUND(100000.0 * SUM(asthma_admissions) / SUM(asthma_population), 1) AS asthma_rate_pooled
FROM quartered
GROUP BY imd_quarter
ORDER BY imd_quarter;
```

**Expected result:** 4 rows.

| imd_quarter | n_boroughs | imd_min | imd_max | pm25_weighted | asthma_rate_pooled |
|---:|---:|---:|---:|---:|---:|
| 1 | 8 | 9.5 | 16.8 | 8.41 | 127.3 |
| 2 | 8 | 17.5 | 23.0 | 8.70 | 161.5 |
| 3 | 8 | 23.3 | 25.9 | 9.12 | 160.0 |
| 4 | 8 | 26.7 | 31.8 | 9.28 | 203.4 |

PM2.5 rises with each quarter, from 8.41 in the least deprived to 9.28 µg/m³ in the most deprived. The asthma rate is lowest in the least deprived quarter and highest in the most deprived, but the two middle quarters are about the same. Both are comparisons of areas, not of people, and deprivation in London is tangled with inner-London geography. `NTILE` splits by row count, not by value, so two boroughs with almost the same score can land in different quarters. `sql/03_deprivation_groups.sql` splits the boroughs into thirds instead, with plain averages of PM2.5 and of the share of deaths attributable to PM2.5.

### Answer 11

```sql
-- 1. Mid-2025 population per area: all ages and aged 30+ (conditional sum)
WITH area_population AS (
    SELECT
        a.area_name,
        SUM(p.population)                                         AS pop_all_ages,
        SUM(CASE WHEN p.age >= 30 THEN p.population ELSE 0 END)   AS pop_30plus
    FROM population AS p
    INNER JOIN areas AS a
        ON p.area_code = a.area_code
    WHERE p.year = 2025
    GROUP BY a.area_name
),

-- 2. Shares within the borough and of London's totals (window sums over all 33 rows)
shares AS (
    SELECT
        area_name,
        pop_all_ages,
        pop_30plus,
        100.0 * pop_30plus / pop_all_ages                   AS pct_30plus_in_area,
        100.0 * pop_all_ages / SUM(pop_all_ages) OVER ()    AS pct_of_london_all_ages,
        100.0 * pop_30plus / SUM(pop_30plus) OVER ()        AS pct_of_london_30plus
    FROM area_population
)

SELECT
    area_name,
    pop_all_ages,
    pop_30plus,
    ROUND(pct_30plus_in_area, 1)                            AS pct_30plus_in_area,
    ROUND(pct_of_london_all_ages, 2)                        AS pct_of_london_all_ages,
    ROUND(pct_of_london_30plus, 2)                          AS pct_of_london_30plus,
    ROUND(pct_of_london_30plus - pct_of_london_all_ages, 2) AS difference_pts
FROM shares
ORDER BY pct_30plus_in_area DESC;
```

**Expected result:** 33 rows. The first three and the last three:

| area_name | pop_all_ages | pop_30plus | pct_30plus_in_area | pct_of_london_all_ages | pct_of_london_30plus | difference_pts |
|---|---:|---:|---:|---:|---:|---:|
| Bromley | 336048 | 225705 | 67.2 | 3.68 | 4.07 | 0.38 |
| Richmond upon Thames | 196713 | 131419 | 66.8 | 2.16 | 2.37 | 0.21 |
| Sutton | 213972 | 138791 | 64.9 | 2.35 | 2.50 | 0.15 |
| ... | | | | | | |
| Barking and Dagenham | 238295 | 131152 | 55.0 | 2.61 | 2.36 | -0.25 |
| Newham | 376542 | 202787 | 53.9 | 4.13 | 3.65 | -0.47 |
| Tower Hamlets | 334240 | 174355 | 52.2 | 3.66 | 3.14 | -0.52 |

Across London, 5,551,776 of 9,122,909 residents (60.9%) were aged 30+ in mid-2025, the same totals as `population_30plus` and `population` in `outputs/results_london.csv`. Bromley is the oldest area on this measure and Tower Hamlets the youngest. That fits the README, where the per-resident break-even runs from £10.52 in Tower Hamlets to £14.39 in Richmond upon Thames (second-oldest here); Bromley is second at £14.27 (`outputs/results_borough.csv`). The order is not identical, because the model uses each area's full age and sex profile, not only the share aged 30+. As the README puts it, boroughs differ by age structure, not by how polluted they are, because the relationship is linear with no threshold.

### Answer 12

```sql
-- 1. PM2.5 in 2018 and 2024 side by side for the 33 London areas
WITH endpoints AS (
    SELECT
        i.area_code,
        a.area_name,
        a.is_city_of_london,
        MAX(CASE WHEN i.year_start = 2018 THEN i.value END) AS pm25_2018,
        MAX(CASE WHEN i.year_start = 2024 THEN i.value END) AS pm25_2024
    FROM indicators AS i
    INNER JOIN areas AS a
        ON i.area_code = a.area_code
    WHERE i.indicator_id = 93867
        AND i.year_start IN (2018, 2024)
        AND a.is_london
    GROUP BY i.area_code, a.area_name, a.is_city_of_london
),

-- 2. Total population per area and year (summed before joining)
area_population AS (
    SELECT
        area_code,
        year,
        SUM(population) AS population
    FROM population
    WHERE year IN (2018, 2024)
    GROUP BY area_code, year
),

-- 3. London's population-weighted fall, each year weighted by its own population
london_fall AS (
    SELECT
        SUM(CASE WHEN ap.year = 2018 THEN e.pm25_2018 * ap.population END)
            / SUM(CASE WHEN ap.year = 2018 THEN ap.population END)
        - SUM(CASE WHEN ap.year = 2024 THEN e.pm25_2024 * ap.population END)
            / SUM(CASE WHEN ap.year = 2024 THEN ap.population END) AS london_fall
    FROM endpoints AS e
    INNER JOIN area_population AS ap
        ON e.area_code = ap.area_code
),

-- 4. Absolute and percentage fall for the 32 boroughs, ranked both ways
ranked AS (
    SELECT
        area_name,
        pm25_2018,
        pm25_2024,
        pm25_2018 - pm25_2024                                    AS fall,
        100.0 * (pm25_2018 - pm25_2024) / pm25_2018              AS pct_fall,
        RANK() OVER (ORDER BY pm25_2018 - pm25_2024 DESC)        AS rank_fall,
        RANK() OVER (ORDER BY (pm25_2018 - pm25_2024) / pm25_2018 DESC) AS rank_pct_fall
    FROM endpoints
    WHERE NOT is_city_of_london
)

SELECT
    r.rank_fall,
    r.area_name,
    ROUND(r.pm25_2018, 2)              AS pm25_2018,
    ROUND(r.pm25_2024, 2)              AS pm25_2024,
    ROUND(r.fall, 2)                   AS fall,
    ROUND(r.pct_fall, 1)               AS pct_fall,
    r.rank_pct_fall,
    ROUND(r.fall - lf.london_fall, 2)  AS fall_minus_london
FROM ranked AS r
CROSS JOIN london_fall AS lf
ORDER BY r.rank_fall;
```

**Expected result:** 32 rows. The first five and the last three:

| rank_fall | area_name | pm25_2018 | pm25_2024 | fall | pct_fall | rank_pct_fall | fall_minus_london |
|---:|---|---:|---:|---:|---:|---:|---:|
| 1 | Waltham Forest | 13.06 | 9.12 | 3.94 | 30.1 | 1 | 0.58 |
| 2 | Barking and Dagenham | 13.04 | 9.13 | 3.91 | 30.0 | 2 | 0.55 |
| 3 | Newham | 13.49 | 9.64 | 3.85 | 28.5 | 7 | 0.49 |
| 4 | Redbridge | 12.67 | 8.97 | 3.70 | 29.2 | 5 | 0.35 |
| 5 | Merton | 12.29 | 8.61 | 3.68 | 29.9 | 3 | 0.32 |
| ... | | | | | | | |
| 30 | Harrow | 11.29 | 8.26 | 3.03 | 26.9 | 23 | -0.32 |
| 31 | Camden | 12.51 | 9.55 | 2.96 | 23.6 | 32 | -0.40 |
| 32 | Bromley | 10.96 | 8.13 | 2.82 | 25.8 | 26 | -0.53 |

Waltham Forest's PM2.5 fell most, by 3.94 µg/m³ (30.1%), first on both measures. London's population-weighted fall was 3.36 µg/m³ (12.25 to 8.90; see Answer 8). Some boroughs move a long way between the two rankings: Kensington and Chelsea is 8th on the absolute fall but 19th on the percentage fall, because it started high. Tower Hamlets, the highest borough in 2024, is 29th on the absolute fall and 31st on the percentage fall: it is top in 2024 partly because its PM2.5 fell less than most. Bromley had the smallest absolute fall but started lowest, so it is 26th on the percentage fall; Camden had the smallest percentage fall.
