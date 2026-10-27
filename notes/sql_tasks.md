# SQL tasks for Lassi: session 1

> **Status, 27 October 2026:** at Lassi's request, an AI coding assistant wrote all three queries (`sql/01_borough_latest.sql`, `sql/02_trends.sql`, `sql/03_deprivation_groups.sql`) and the tests pass. This sheet is kept as practice: try writing each query yourself from the spec below before reading the committed version. `notes/sql_practice.md` has more exercises.

Two queries to write: `sql/01_borough_latest.sql` and `sql/02_trends.sql`. Both run against `data/london_air.duckdb`. Task 3 (`sql/03_deprivation_groups.sql`) comes in session 3.

## How to run your SQL

**Option A: no install.** Write the query in any text editor and paste it into the chat. I run it and the tests, show you the output, and commit it with you as the author.

**Option B: run it yourself** (better practice for live SQL tests). In PowerShell:

```powershell
winget install --id Git.Git -e
winget install --id DuckDB.cli -e
```

Close and reopen PowerShell so the new commands are found, then:

```powershell
git clone https://github.com/LKOTA97/london-air-health.git
cd london-air-health
duckdb -readonly data/london_air.duckdb
```

The repository is private, so Git will ask you to sign in to GitHub the first time. At the `D` prompt you can type SQL directly, or run your file with `.read sql/01_borough_latest.sql`. Leave with `.quit`.

To commit your work (first time only, set your name and email):

```powershell
git config --global user.name "Lassi Kotamäki"
git config --global user.email "<your email>"
git pull
git add sql/01_borough_latest.sql
git commit -m "Add query for latest values by borough"
git push
```

The package IDs were checked against the winget index on 27 October 2026 (Git 2.56, DuckDB CLI 1.5.6). The database is saved in a format DuckDB 1.2 and later can read.

## Good practice for both queries

- One CTE per step, with a one-line comment above each saying what it does.
- Explicit `JOIN ... ON`. No commas between tables in `FROM`.
- No `SELECT *` in the final output: name every column.
- Finish with `ORDER BY`.

## The tables you need

`indicators`: one row per area, indicator and period.

| column | type | notes |
|---|---|---|
| area_code | VARCHAR | E09... London areas, E12000007 London region, E92000001 England |
| area_name | VARCHAR | |
| area_type | VARCHAR | 'Local authority', 'Region' or 'Country' |
| indicator_id | INTEGER | see the list below |
| indicator_key | VARCHAR | readable name for the ID |
| indicator_name | VARCHAR | full Fingertips name |
| period | VARCHAR | as published: '2024', '2023/24', '2019 - 23' |
| year_start | INTEGER | first calendar year of the period: 2023 for '2023/24' |
| sex, age | VARCHAR | one breakdown per indicator, so you don't need to filter on these |
| value | DOUBLE | the indicator value |
| lower_ci, upper_ci, count, denominator | DOUBLE | blank where Fingertips has none |
| value_note | VARCHAR | for example 'Value for Hackney and City of London combined' |

| indicator_id | indicator_key | what it is |
|---|---|---|
| 93867 | pm25_concentration | annual mean PM2.5, µg/m³, 2018 to 2024 |
| 93861 | pm25_mortality_share | % of deaths at 30+ attributable to PM2.5, 2018 to 2024 |
| 90810 | asthma_admissions_u19 | asthma admissions under 19, crude rate per 100,000, 2013/14 to 2024/25 |
| 92302 | copd_admissions_35plus | emergency COPD admissions 35+, directly standardised rate per 100,000, 2010/11 to 2023/24 |
| 94240 | imd_2025_score | IMD 2025 score: use this one |
| 93553 | imd_2019_score | IMD 2019 score (kept for reference, not used) |
| 93250, 93823 | mortality_... | all-cause mortality (for the model, not these tasks) |

`areas`: area_code, area_name, area_type, is_london (true for the 33 E09 areas, including the City of London), is_city_of_london.

`population`: area_code, sex ('Male'/'Female'), age (0 to 90, where 90 means 90 and over), population, year (2018 to 2025). One row per area, sex, single year of age and year.

## Task 1: `sql/01_borough_latest.sql`

**Spec.** One row per London area (33 rows) with the latest value of each indicator. "Latest" means the highest `year_start` that indicator has for London areas, which differs between indicators. Use IMD 2025 (94240) for `imd_score`.

**Columns, in this order:**

| column | meaning |
|---|---|
| area_code, area_name | |
| pm25 | latest PM2.5 |
| pm25_year | its year (integer) |
| attributable_pct | attributable % for the same year |
| imd_score | IMD 2025 score |
| asthma_u19_rate | latest asthma rate |
| asthma_u19_period | its period label, for example '2024/25' |
| copd_rate | latest COPD rate |
| copd_period | its period label |
| pm25_rank | 1 = highest PM2.5. The City of London is not ranked: its rank is NULL, and the other 32 are ranked 1 to 32 |
| is_city_of_london | |

Order by `pm25_rank`, with the City of London last.

**Expected output:** 33 rows. First three and last:

|area_code |area_name      |  pm25| pm25_year| attributable_pct| imd_score| asthma_u19_rate|asthma_u19_period | copd_rate|copd_period | pm25_rank|is_city_of_london |
|:---------|:--------------|-----:|---------:|----------------:|---------:|---------------:|:-----------------|---------:|:-----------|---------:|:-----------------|
|E09000030 |Tower Hamlets  |  9.81|      2024|             7.28|     30.55|          156.78|2024/25           |    501.20|2023/24     |         1|FALSE             |
|E09000033 |Westminster    |  9.71|      2024|             7.20|     23.93|          186.49|2024/25           |    227.83|2023/24     |         2|FALSE             |
|E09000019 |Islington      |  9.69|      2024|             7.19|     26.65|          157.67|2024/25           |    374.24|2023/24     |         3|FALSE             |
|E09000001 |City of London | 10.96|      2024|             8.09|     10.21|              NA|2024/25           |        NA|2023/24     |        NA|TRUE              |

(Values are rounded here; your query should return them unrounded. NA shows as NULL in DuckDB.)

**Hints:**
1. Start with a CTE that finds the latest `year_start` for each indicator, then join it back to `indicators` on both the indicator and the year.
2. To turn one row per indicator into one column per indicator, group by area and use conditional aggregation: `MAX(CASE WHEN indicator_id = 93867 THEN value END) AS pm25`.
3. Rank in a separate CTE that leaves out the City of London, then `LEFT JOIN` the ranks back so the City keeps its row with a NULL rank.

## Task 2: `sql/02_trends.sql`

**Spec.** PM2.5 and attributable % for each year from 2018 to 2024, stacked in one long table:
- each of the 33 London areas,
- London as a whole, as a population-weighted mean of the 33 areas, using each year's own population,
- England, as published by Fingertips.

**Columns, in this order:** year, area_code, area_name, area_group, pm25, attributable_pct.
- `area_group` is 'Borough', 'London' or 'England'.
- For the London rows use area_code 'LONDON' and area_name 'London (population-weighted)'.

Order by area_group, area_code and year.

**Expected output:** 245 rows (33 × 7 borough rows, 7 London rows, 7 England rows). Some rows:

| year|area_code |area_name                    |area_group |  pm25| attributable_pct|
|----:|:---------|:----------------------------|:----------|-----:|----------------:|
| 2018|E09000002 |Barking and Dagenham         |Borough    | 13.04|             9.55|
| 2018|LONDON    |London (population-weighted) |London     | 12.25|             9.00|
| 2024|LONDON    |London (population-weighted) |London     |  8.90|             6.62|
| 2018|E92000001 |England                      |England    |  9.52|             7.07|
| 2024|E92000001 |England                      |England    |  7.06|             5.29|

As a check, Fingertips publishes an official London figure (area code E12000007 in `indicators`). Your weighted mean should be within about 0.02 µg/m³ of it every year. A plain average misses by up to 0.07.

**Hints:**
1. The population table has one row per area, sex and age. Sum it to one row per area and year in its own CTE *before* joining, so each indicator row matches exactly one population row.
2. A weighted mean is `SUM(value * population) / SUM(population)`, grouped by year. Join on area and year, so 2018 values are weighted by 2018 population.
3. Build the borough, London and England rows in separate CTEs with identical columns, then stack them with `UNION ALL`.

## How your queries are checked

`tests/testthat/test-sql.R` runs each file once it exists. It checks:
- the column names and row count,
- the latest periods,
- that values match the indicators table,
- that the City of London is flagged and not ranked,
- that ranks 1 to 32 follow PM2.5,
- that the London rows equal a population-weighted mean calculated separately in R,
- and that they sit close to the official Fingertips London figure.

Run all tests with `Rscript -e "testthat::test_dir('tests/testthat')"` once R is set up, or ask me to run them.
