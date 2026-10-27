# Walkthrough

Every script and query in the order they run: what each does and why it is built that way. Read it before an interview with the code open next to it. The reasons for individual data and modelling choices are in `notes/decision_log.md` (D1 to D23). The source quotes, with page numbers, are in `notes/verified_sources.md`.

## Who did what

- **Lassi** chose the question and wrote the project brief (data sources, model design, SQL tasks, dashboard pages, writing rules). Lassi decided to use IMD 2025 instead of IMD 2019 (D8), then asked an AI coding assistant to complete the remaining work.
- **An AI coding assistant** wrote all the code: the R scripts, the three SQL queries (originally planned as Lassi's own task), the model, the tests, the dashboard (including the deprivation chart, also originally planned as Lassi's) and these notes.
- **Sources** were checked by AI agents. They downloaded the primary documents (COMEAP, NICE, Green Book, legislation, ONS, EEPRU) and recorded quotes with page numbers in `notes/verified_sources.md`. A second agent re-checked each one.
- **Independent checks** of the model (a re-implementation, a code review and a methods review) are described near the end of this note.
- **Still to do:** Lassi needs to read the code and re-check the key sources in person before interviews. The last section lists what to cover.

## How the pieces fit

```
R/00_setup.R         packages, paths, constants  (loaded by every script)
R/01 to 03           download raw data           ->  data/raw/ (+ MANIFEST.csv)
R/04                 tidy and load               ->  data/clean/*.csv and data/london_air.duckdb
sql/01 to 03         query the database          ->  read by the dashboard (all three) and R/07 (01 and 02)
R/model_functions.R  the life-table model (functions only)
R/05                 base-case model             ->  outputs/ (results, break-even, checks)
R/06                 sensitivity analysis        ->  outputs/ (one-way, tornado, PSA)
R/07                 fill the README template    ->  README.md
tests/testthat/      check data, SQL and model
index.qmd            Quarto dashboard            ->  docs/ (for GitHub Pages)
```

## Key results

Base case: residents aged 30 and over in mid-2025, HR 1.08 per 10 µg/m³, US EPA lag, EQ-5D-5L, England death rates, 3.5% discounting, £20,000 per QALY, spending spread over 20 years.

| Result | Value | File |
|---|---|---|
| QALYs gained across London, discounted | 82,670 | `outputs/results_london.csv` |
| Life-years gained, undiscounted | 318,407 (20.9 days per resident aged 30+) | `outputs/results_london.csv` |
| Break-even present value at £20,000 per QALY | £1,653.4m | `outputs/results_london.csv` |
| Break-even spend a year over 20 years | £116.3m, or £12.75 per resident (all ages) | `outputs/results_london.csv` |
| 95% interval per resident (hazard ratio only) | £10.47 to £15.04 | `outputs/psa_summary.csv` |
| Break-even spend a year over 10 or 30 years instead | £198.8m or £89.9m a year | `outputs/breakeven.csv` |
| Cut lasts only while paid for, 10, 20 or 30 years | £64.1m, £68.2m or £70.5m a year | `outputs/breakeven_temporary_cut.csv` |
| Range across boroughs, per resident | £10.52 (Tower Hamlets) to £14.39 (Richmond upon Thames) | `outputs/results_borough.csv` |

The chain from QALYs to the headline: 82,670 QALYs x £20,000 = £1,653.4m. Divided by the 20-year annuity factor at 3.5% (14.21), that is £116.3m a year. Divided by London's 9,122,909 residents, it is £12.75 each.

## Running it: R/run_all.R

`Rscript R/run_all.R` runs scripts 01 to 07 in order, then every test.

- Each script is sourced in a fresh environment (`local = new.env()`), so no script can quietly depend on variables left behind by an earlier one.
- The tests run with `stop_on_failure = TRUE`, so a failing test stops the run with an error.
- Scripts 01 to 03 download the data again from the internet.
- The dashboard is built separately with `quarto render`.

On 27 October 2026 the suite ran 110 checks in 29 tests (data 37, model 41, SQL 32), all passing.

## Environment

- **renv** records every package version in `renv.lock`, so `renv::restore()` rebuilds the same library on any machine.
- Packages come from a dated Posit Package Manager snapshot (26 October 2026, set in `.Rprofile`). Every machine gets the same versions, and Windows and macOS get ready-built binaries, so they should not need a compiler (Rtools on Windows).
- `DESCRIPTION` lists the packages the project uses, and renv snapshots from it (`snapshot.type = "explicit"`). This keeps dashboard-only packages such as leaflet in the lockfile.

## R/00_setup.R

Loaded at the top of every script. It sets:
- the packages,
- the folder paths, built with `here()` so they work from any working directory on Windows or Linux,
- the eight Fingertips indicator IDs: PM2.5, attributable deaths, asthma and COPD admissions, IMD 2025 (used) and IMD 2019 (reference only), and two all-cause mortality measures (the SMR used in the borough mortality scenario, and the rate it was compared with in D9),
- `options(timeout = 300)`, because ONS files can take more than R's default 60 seconds,
- two helpers: `download_to()` tries a download up to three times (`httr2::req_retry(max_tries = 3)`); `record_download()` adds or replaces the file's row in `data/raw/MANIFEST.csv`.

## R/01_get_fingertips.R

Downloads the eight indicators from the OHID Fingertips API at upper-tier local authority level (area type 502). It keeps the 33 London areas (codes starting E09) and England.

- Every column is read as text and written straight back. Converting to numbers and back can change how a value is written, and the raw folder should hold exactly what the API sent.
- It also saves the indicator metadata. That file is the evidence for how each indicator is calculated, including the COMEAP coefficient behind 93861.
- It saves Fingertips' own London region values for PM2.5 and the attributable fraction. They are only used to check our population-weighted London mean.

Things found while building it:
- The England rows appear twice in each file (once with England as its own "parent"). Step 04 removes the duplicate.
- For asthma and COPD admissions the City of London has no value of its own. Hackney's value covers both.

## R/02_get_ons.R

**Population.** Gets mid-year population by single year of age and sex from Nomis dataset NM_2002_1, for 2018 to 2025.
- Geography `2013265927TYPE423` means "every county or unitary authority (as of April 2023) inside the London region".
- Nomis returns at most 25,000 rows per request, so it asks for one year at a time.
- It stops with an error unless each year has 33 areas, 91 ages, and a borough sum equal to the Nomis London total.

**Life tables.** Downloads the ONS National life tables for England (released 10 December 2025, latest period 2022 to 2024). The file is pinned because its name changes with each edition.

## R/03_get_other.R

- **EQ-5D-5L by age and sex** (the base case). Hernández Alava and Wailoo (2026), EEPRU Report 082, sheet "Predictions". NICE PMG51 (27 August 2026) points to these norms (D12).
- **EQ-5D-3L by age and sex** (comparison only). The NICE DSU spreadsheet (Hernández Alava, Pudney and Wailoo, 2022). It is an old-format `.xls` file, although the website does not say so.
- Neither spreadsheet has an open licence statement, so git ignores the originals and only the tidy values are committed.
- **Borough boundaries.** Local Authority Districts (May 2026), ultra-generalised. The query asks the ONS Open Geography Portal's ArcGIS service for E09 codes only, already in WGS84 coordinates for leaflet. The file is 25 KB, so it needs no further simplification for phones.

## R/04_build_db.R

Turns the raw files into five tidy tables, writes them to `data/clean/` as CSV (plus the boundaries as GeoJSON), and loads the tables into DuckDB.

| Table | One row per |
|---|---|
| indicators | area, indicator, period |
| areas | area (33 London areas, London region, England) |
| population | area, sex, single year of age (0 to 89, then 90 meaning 90 and over), year |
| life_table | sex, age 0 to 100 (England, 2022 to 2024) |
| utility_norms | EQ-5D version (5L or 3L), sex, single year of age |

Key steps:
- Fingertips files hold several breakdowns per indicator (deprivation deciles, male, female, age bands). Rows with a `Category Type` (the deprivation deciles) are dropped first. A small lookup table `keep_breakdown` then names the sex and age breakdown to keep for each indicator, and `semi_join` filters to it.
- `year_start` comes from Fingertips' sortable period field (YYYY0000). This handles "2018", "2023/24" and pooled periods like "2019 - 23" the same way.
- The life table sheet has males and females side by side. The script checks the header row says exactly `age, mx, qx, lx, dx, ex` before using it, so a layout change in a future ONS edition fails loudly instead of silently.
- The two EQ-5D spreadsheets put the sexes in different column orders (5L: males first; 3L: females first), so the script names the columns explicitly for each file.
- The database is rebuilt from scratch every run. It is saved in a storage format that DuckDB 1.2 and later can read, so older DuckDB tools can open it (D10).

## Tests: tests/testthat/test-data.R

`helper-db.R` gives every test file `query_db()`, which opens the database read-only, runs one query and closes it.

| Check | Why |
|---|---|
| Every indicator has 33 London areas in its latest period | catches a dropped area |
| No duplicate area, indicator, period, sex and age | catches join or filter mistakes |
| PM2.5 between 3 and 20; attributable % between 2 and 12 | catches unit or parsing errors |
| **Validation:** 93861 = `100 * (1 - 1.08^(-C/10))` for every London area and year | ties the model's hazard ratio to the official statistic |
| City of London admissions blank, Hackney flagged | documents the combined values |
| Area codes agree across indicators, population and boundaries | joins will not silently lose an area |
| Population, life table and utilities complete | the model needs every age |
| EQ-5D at age 30 matches the published values (5L: 0.935 men, 0.912 women; 3L: 0.923 and 0.904) | catches the two sexes being swapped |

The validation test has teeth: the maximum difference is 0.00004 with 1.08 (the test allows up to 0.01), but more than 1 percentage point with 1.07 or 1.09 (D11).

## SQL: the three queries

An AI coding assistant wrote all three queries at Lassi's request; they were originally planned as Lassi's own task. `notes/sql_tasks.md` keeps the original specs for queries 01 and 02 as practice: try writing each one yourself before reading the committed version.

All three follow the same house style: one CTE per step with a comment above it, explicit joins (`JOIN ... ON`, and one `CROSS JOIN` in query 03), no `SELECT *` in the final output, and a closing `ORDER BY`. The dashboard and `R/07_write_readme.R` run the files directly, so the committed SQL is what produces the published numbers.

### sql/01_borough_latest.sql: latest values by borough

One row per London area (33 rows) with the latest value of each indicator.

| CTE | What it does |
|---|---|
| `latest_period` | `MAX(year_start)` for each indicator, looking only at London areas (`LIKE 'E09%'`), so a period published for England alone is never chosen |
| `latest_values` | `INNER JOIN` of `indicators` to `latest_period` on indicator and year, keeping the five indicators the page needs |
| `borough_wide` | Pivots to one column per indicator with conditional aggregation, `MAX(CASE WHEN indicator_id = ... THEN value END)`. `INNER JOIN` to `areas` with `WHERE a.is_london` drops the England rows |
| `pm25_ranks` | `RANK() OVER (ORDER BY pm25 DESC)` over the 32 boroughs, with `WHERE NOT is_city_of_london` |
| final `SELECT` | `LEFT JOIN` of the ranks back to all 33 areas, `ORDER BY pm25_rank NULLS LAST` |

Why it is built this way:
- **"Latest" differs by indicator:** PM2.5 2024, asthma 2024/25, COPD 2023/24, IMD 2025. One global year would leave some columns empty.
- **`MAX` in the pivot** only picks the single value each area has for each indicator in that period. Any aggregate would do; `MAX` also ignores the NULLs from the other indicators.
- **City of London left out of the ranking:** its PM2.5 (10.96 µg/m³) is the highest in London, but it has by far the fewest residents: 15,631 in mid-2025, against 145,734 in the next smallest area, Kensington and Chelsea (`population` table; see D2). Ranking it would make it number 1 and push every borough down one place. Ranking in a separate filtered CTE, then joining back with `LEFT JOIN`, keeps the City's row with a blank rank. An `INNER JOIN` would drop it.
- **`RANK` rather than `ROW_NUMBER`:** tied values would share a rank instead of being split arbitrarily. There are no ties in 2024.

Result: Tower Hamlets ranks 1 (9.81 µg/m³) and Bromley 32 (8.13).

### sql/02_trends.sql: trends with a population-weighted London mean

PM2.5 and the attributable share of deaths, 2018 to 2024, for each of the 33 areas, for London and for England.

| CTE | What it does |
|---|---|
| `air_quality` | Pivots PM2.5 (93867) and attributable % (93861) to one row per area and year |
| `population_total` | `SUM(population)` by area and year: all ages, both sexes |
| `borough_rows` | `INNER JOIN` to `areas`, London areas only, as published |
| `london_rows` | `INNER JOIN` to `population_total` on area and year; weighted mean `SUM(value * population) / SUM(population)`, grouped by year |
| `england_rows` | England as published by Fingertips |
| final | `UNION ALL` of the three groups, ordered by group, area and year |

Why it is built this way:
- **Population is summed before the join.** The population table has 182 rows per area and year (2 sexes x 91 ages). Joining it unsummed would repeat each air quality row 182 times (a "fan-out"). This particular ratio happens to survive that, because the repeats cancel, but any `COUNT`, `AVG` or unweighted `SUM` would be wrong. Summing first makes the join one-to-one, which is the safe habit and easy to check.
- **The join also does the filtering.** The population table holds only the 33 London areas, so the England and London region rows in `air_quality` find no match and drop out of the London mean.
- **Each year is weighted by its own mid-year population** (D4). The attributable fraction is weighted by all-ages population rather than deaths at 30+, a simplification that matches the official London figure to within 0.02 percentage points.
- **`UNION ALL`, not `UNION`:** the three groups cannot overlap, so a duplicate check would only cost time.

Result: 245 rows (35 series x 7 years). London's weighted PM2.5 falls from 12.3 µg/m³ in 2018 to 8.9 in 2024 (England 7.1), within 0.02 µg/m³ of the official London figure every year.

### sql/03_deprivation_groups.sql: deprivation thirds

Splits the 32 boroughs into thirds by IMD 2025 score and gives mean PM2.5 and attributable % for each third in the latest year.

| CTE | What it does |
|---|---|
| `latest_year` | `MAX(year_start)` for PM2.5: 2024 |
| `borough_values` | `INNER JOIN` of `areas` to `indicators`, `CROSS JOIN` to `latest_year`, City of London excluded. Pivots to IMD score, PM2.5 and attributable % for the latest year |
| `deprivation_thirds` | `NTILE(3) OVER (ORDER BY imd_score)` |
| final | Per third: number of boroughs, IMD range, `AVG` PM2.5 and attributable % |

Why it is built this way:
- **`CROSS JOIN` to a one-row CTE** attaches the latest year to every row, so the pivot can pick 2024 values without a hard-coded year. IMD 2025 has a single period, so it needs no year filter.
- **`NTILE(3)`** sorts the rows and deals them into three groups as equal as possible. With 32 boroughs that is 11, 11 and 10; the extra rows go to the first groups. Ascending order makes third 1 the least deprived.
- **City of London left out**, as for the ranking (D2).
- **Simple means across boroughs,** not population-weighted: the comparison is of areas, not people. It is ecological and tangled with inner-London geography.

Result (2024):

| Third | Boroughs | IMD 2025 score | Mean PM2.5 (µg/m³) | Mean attributable % |
|---|---|---|---|---|
| Least deprived | 11 | 9.5 to 19.9 | 8.45 | 6.29 |
| Middle | 11 | 20.3 to 24.9 | 9.09 | 6.76 |
| Most deprived | 10 | 25.5 to 31.8 | 9.21 | 6.84 |

## Tests: tests/testthat/test-sql.R

The expected values are calculated in R from the `indicators` and `population` tables, independently of the SQL. Each test skips if its file is missing, a leftover from when Lassi was to write them; all three files now exist.

| Query | What the test checks |
|---|---|
| 01 | The expected set of columns; 33 rows, unique, all E09. Latest periods are 2024, 2024/25 and 2023/24. PM2.5 equals the `indicators` table. Attributable % equals `100 * (1 - 1.08^(-PM2.5/10))`. IMD is the 2025 indicator (94240), not 2019. The City is flagged, unranked and has blank admissions. Ranks are 1 to 32 and match R's `rank(-pm25, ties.method = "min")`, which is what SQL `RANK` does |
| 02 | Columns; 245 rows; years 2018 to 2024; three groups. The London rows equal a weighted mean computed in R to within 1e-8, and lie within 0.05 µg/m³ of the official London figure. The England rows equal the published values |
| 03 | 3 rows covering 32 boroughs, year 2024. Group sizes and means equal an R version using `dplyr::ntile()` to within 1e-10 |

The tests were run against two deliberate mistakes, a plain average for London and ranking the City of London, and both fail.

## R/model_functions.R: the life-table model

Functions only. `R/05_model.R`, `R/06_sensitivity.R` and the model tests all use them, so there is one copy of the model.

### The model in one block

For one person of a given sex who is age `a` in year 1 of the cut:

```
for each year t = 1, 2, ... until age 100:
  mx(t)      = England death rate at age a + t - 1        (x SMR/100 in the SMR scenario)
  mx_cut(t)  = mx(t) * (1 - lag(t) * (1 - 1.08^(-1/10)))
  S(t)       = exp(-(mx(1) + ... + mx(t)))                survival to the end of year t, S(0) = 1
                                                          (S_cut(t) is the same with mx_cut)
  LY(t)      = (S(t-1) + S(t)) / 2                        mid-year life-years (LY_cut(t) from S_cut)
  gain(t)    = LY_cut(t) - LY(t)
QALYs gained, discounted = sum over t of gain(t) * utility(age a + t - 1, sex) / 1.035^t
```

Borough totals are these per-person gains times the number of residents of that sex and age.

### Step by step

1. **Parameters.** `read_parameters()` reads `model/parameters.csv` as text. `param_num()` converts one value and stops if it is missing or not a number, so a typo fails loudly instead of becoming NA. `param_bound()` reads a low or high value. `base_settings()` collects the base case in one list; every scenario copies it with `modifyList()` and changes one entry.
2. **Inputs.** `load_model_inputs()` runs five read-only queries: the life table, the utility norms, the 2025 population, the 33 London areas and the borough SMRs.
3. **The 90+ split.** ONS gives one "90 and over" group. `split_90_plus()` shares it out over single years 90 to 100 in proportion to the England life table's stationary population: `l` is built from `qx`, and `L = (l(x) + l(x+1)) / 2`. A test checks the total is unchanged.
4. **Cohorts.** One cohort per sex and single year of age, 30 to 100: 71 a sex, 142 in all. `cohort_gains()` lays them out as a matrix, one row per cohort and one column per year of follow-up. A 30-year-old is followed for 71 years. For older cohorts the columns past age 100 are kept for shape but zeroed (`in_range`), and the ages are capped at 100 for look-ups (`age_used`).
5. **Death rates, mx.** The ONS central death rate for that age and sex (England, 2022 to 2024), held fixed in every year. This is period, not projected, mortality: no future fall in death rates is assumed.
6. **Hazard multiplier.** `hazard_multiplier()` is `HR^(-delta/10)`: 1.08^(-0.1) = 0.9923 for a 1 µg/m³ cut, so death rates fall by 0.77% at every age at the full effect. The ratio is applied to `mx` because a hazard ratio acts on a rate, not on a probability.
7. **Lag in calendar time.** `lag_share(t)` is the share of the full effect in force in year t of the cut: 30% in year 1, 12.5 points more in each of years 2 to 5, 1.333 points more in each of years 6 to 20, so 30, 42.5, 55, 67.5, 80% and 100% by year 20 (D16). `mx_cut = mx * (1 - share * (1 - 0.9923))`. The share depends on the years since the cut began, not on age, so open-cohort entrants are already partly protected when they join (D19).
8. **Survival.** `S(t) = exp(-cumulative mx)`. That is the same as applying `qx = 1 - exp(-mx)` year by year (a constant hazard within each year). The cumulative sum along each row is one matrix product with an upper-triangular matrix of ones, so all 71 cohorts of a sex are done at once.
9. **Mid-year life-years.** Life-years in a year are `(S at the start + S at the end) / 2`: people who die during a year live, on average, half of it. Follow-up stops after the year lived at age 100, a small underestimate.
10. **Gains.** Life-years with the cut minus life-years without, cohort by cohort and year by year.
11. **QALYs.** Each year's life-year gain times the EQ-5D-5L norm for that age and sex.
12. **Discounting.** Each year's gain times `1 / (1 + r)^t`, where t is the year of the cut (1, 2, ...). Year 1 is discounted too (D20). Spending is discounted the same way, so the annual break-even does not depend on this convention.
13. **From people to boroughs.** `person_gains()` returns per-person gains by sex and age. `borough_gains()` splits the 90+ group, joins the per-person gains to the population by sex and age, multiplies, and sums by borough. A final `right_join` to `areas` keeps all 33 areas.
14. **Open cohort (scenario).** Adds 19 more cohorts a sex: people who turn 30 in each of years 2 to 20. They are matched to residents aged 29 down to 11 in mid-2025, and discounting runs from the calendar year, so their gains are discounted from year 2 onwards. It assumes no deaths before 30 and no migration (D18).
15. **SMR scenario.** Each borough's death rates are England's times its all-cause SMR / 100 (Fingertips 93250, deaths 2019 to 2023, England = 100) at every age (D9). Per-person gains are recalculated for each borough. The function first checks that every area has exactly one SMR.
16. **Temporary cut (comparison).** With `cut_years = H` the share is `lag(t) - lag(t - H)`. Ending the cut is a second change in concentration, of the opposite sign, so the benefit fades on the same lag (D17). For H = 20: 100% in year 20, 70% in year 21, 57.5% in year 22, zero from year 40.
17. **Break-even.** `annuity_factor(h, r)` is `sum of 1 / (1 + r)^t for t = 1 to h`: 8.32, 14.21 and 18.39 for 10, 20 and 30 years at 3.5%. `breakeven_pv()` is discounted QALYs times the threshold. `breakeven_annual()` divides that by the annuity factor. So £1m of present value is £120,241 a year over 10 years, £70,361 over 20 and £54,371 over 30 (`outputs/annuity_factors.csv`).
18. **Life expectancy check.** `life_expectancy()` runs the same survival calculation with no cut. At age 30 it gives 53.87 years for women against ONS's 53.90, and 50.28 for men against 50.28.

## R/05_model.R: base case

Reads the parameters, settings and inputs, runs `borough_gains()` once for the base case, adds London as the sum of the 33 areas, and writes:

| File | Contents |
|---|---|
| `results_borough.csv`, `results_london.csv` | Life-years and QALYs gained (undiscounted and discounted), population (all ages and 30+), QALYs per 100,000 aged 30+, days per person aged 30+, present value, annual break-even (£20,000, 20 years), per resident |
| `breakeven.csv` | 34 areas (the 33 plus London) x 5 values per QALY x 3 horizons: 510 rows |
| `breakeven_temporary_cut.csv` | The cut-lasts-while-paid-for view at 10, 20 and 30 years, for the four NICE thresholds |
| `annuity_factors.csv` | The annuity factor and the annual equivalent of £1m for each horizon |
| `london_gains_by_year.csv` | London's closed-cohort gains in each of 71 years, with the lag share |
| `model_checks.csv` | Life expectancy at 30 against ONS, and the hazard multiplier |

Points to know:
- **Values per QALY.** £20,000 (NICE guidelines, PMG20 Box 7.2) is the base. Also £30,000 (NICE's previous upper bound), £25,000 and £35,000 (technology appraisals only) and £84,548, the societal value from Defra's air quality guidance (D13, D15).
- **The societal value uses Green Book conventions:** QALYs discounted at 1.5% (152,277 for London), spending at 3.5%. That gives £905.9m a year over 20 years. It is a cost-benefit value, not the NHS's opportunity cost, so it is labelled separately.
- **"Per resident" divides by all residents** (9,122,909). "Days per person" and "per 100,000" use residents aged 30 and over (5,551,776), the people who gain.
- **The bug the code review found.** Inside `summarise()`, once `population = sum(population)` has run, later lines see the sum rather than the column. So `sum(population[age >= 30])` written after it came out missing. The 30+ total is now computed first, with a comment saying why, and a test guards it.
- **Shape over time.** Undiscounted life-years gained peak in year 39 of the cut. Only 30% of the discounted QALYs fall in the first 20 years, which is why the spending horizon matters so much.

## R/06_sensitivity.R: one-way analysis, tornado and PSA

`london_result()` runs `borough_gains()` for one set of settings, sums the discounted gain over London and returns the annual break-even at £20,000.

### One-way analysis

Eleven scenarios across seven inputs, each changing one thing from the base case (`outputs/oneway.csv`):

| Input | Scenario | £m a year |
|---|---|---|
| Base case | | 116.3 |
| Hazard ratio | HR 1.06 / 1.09 (95% limits) | 88.1 / 130.3 |
| Cessation lag | No lag | 130.9 |
| Discount rates | 1.5% both (NICE PMG20) | 177.4 |
| | 1.5% health, 3.5% costs (Green Book) | 214.3 |
| | 3.0% both (Discount Rate Review) | 128.4 |
| Cohort | Open cohort | 144.7 |
| Health outcome | Life-years, not QALYs | 143.5 |
| Baseline mortality | Borough SMR | 114.9 |
| Horizon | 10 / 30 years | 198.8 / 89.9 |

### Tornado

For each input, the lowest and highest result, with the base case always counted as one of the possible values. So when every alternative moves the answer the same way, the base case is one end of the bar: this applies to the inputs with a single alternative and to the discount rates, whose three scenarios all raise the answer. Inputs are sorted by the width of the bar (`outputs/tornado.csv`). The horizon is widest, then the discount rates, then the hazard ratio.

### The factor-of-two rule

Any input whose high result is more than twice its low is flagged. Only the horizon crosses it (198.8 / 89.9 = 2.21). For flagged inputs the script writes every borough's result at each value and at the base case (`outputs/factor_of_two.csv`), so no single number hides the spread. That is why the dashboard's borough table shows 10, 20 and 30 years side by side (D22).

### Comparisons, kept out of the tornado

Two results answer a different question rather than measuring uncertainty, so they sit in `outputs/comparisons.csv` (D22):
- EQ-5D-3L norms, the pre-2026 NICE method: £106.5m a year (0.92 of the base).
- The cut lasts only while it is paid for (20 years): £68.2m a year (0.59 of the base).

### Probabilistic sensitivity analysis (PSA)

- **What is drawn.** Only the hazard ratio: 5,000 draws (seed 2026) of `log(HR) ~ Normal(log(1.08), 0.0071196)`. The standard error is `(log(1.09) - log(1.06)) / (2 * 1.96)`.
- **Check on the draws.** The drawn 2.5th, 50th and 97.5th percentiles are 1.065, 1.080 and 1.095, against the published 1.06, 1.08 and 1.09. The published interval is slightly asymmetric on the log scale, so a symmetric draw cannot match both ends (`outputs/psa_hr_check.csv`).
- **Held fixed.** Utilities, life tables and population. D12 gives the reasons for the utilities: their uncertainty is second-order next to the hazard ratio, and the sources give parameter covariances, not standard errors, for the predicted means.
- **The population matrix trick.** With England death rates, the per-person gains depend on the hazard ratio but not on the borough. So the script builds one matrix of residents aged 30+: 33 areas by 142 sex-and-age cells. Each draw computes only the 142 per-person discounted QALYs. One matrix product, (33 x 142) times (142 x 5,000), then gives every borough's QALYs in every draw. Running `borough_gains()`, with its joins and the 90+ split, 5,000 times would get the same answer much more slowly.
- **Results** (`outputs/psa_summary.csv`, one row per area and London): London's median is £116.3m a year, 95% interval £95.5m to £137.2m, or £10.47 to £15.04 per resident. All 5,000 London draws are in `outputs/psa_draws_london.csv`.

### Acceptability curve

For each annual scheme cost per resident (£0 to £29 in 10p steps), the share of draws in which the break-even spend is at least that cost (`outputs/acceptability.csv`). The £30,000 curve scales each draw by 1.5, because break-even is proportional to the threshold.

| Value per QALY | Cost-effective in at least 95% of draws up to | In at least half up to |
|---|---|---|
| £20,000 | £10.80 per resident a year | £12.70 |
| £30,000 | £16.20 | £19.10 |

## Tests: tests/testthat/test-model.R

| Check | Why |
|---|---|
| Hazard multiplier for 1 µg/m³ is about 0.9923 | the core formula |
| Lag reaches 30%, 42.5%, 80% and 100% in years 1, 2, 5 and 20, never falls, and is 100% with no lag | the lag matches COMEAP |
| Life expectancy at 30 within 0.5 years of ONS, each sex | the survival maths reproduces the life table |
| Splitting the 90+ group keeps the total | no one is lost or added |
| HR = 1 gives exactly zero gain | no gain without an effect |
| A 2 µg/m³ cut gives about twice the gain of 1 µg/m³ (within 2%) | close to linear, as expected for small cuts |
| QALYs below life-years; discounted below undiscounted | utilities are below 1; discounting shrinks |
| Every borough gains | catches a broken join |
| London total equals the sum of boroughs in the saved files | outputs are consistent |
| No lag, open cohort, 1.5% discounting and HR 1.09 raise the gain; HR 1.06 lowers it | scenarios move the right way |
| Annuity factor equals the closed form `(1 - 1.035^-20) / 0.035`; annual = PV / annuity; annual falls as the horizon lengthens | the break-even formula |
| Saved results have no missing values; 30+ populations add up and are below the totals | the regression test for the code review's bug |
| A cut that ends fades on the same lag (70% in year 21, zero by year 40), gains less than a permanent cut, and `cut_years = Inf` equals the base | the temporary-cut logic |
| The societal value uses Green Book discounting; NICE thresholds do not | the two discount conventions are not mixed up |

## R/07_write_readme.R

Fills `README_template.md` and writes `README.md`, so no number in the README is typed by hand.

- Runs SQL 01 and 02 for the descriptive figures, and reads the model outputs and `model/parameters.csv` for the rest.
- Each `{{placeholder}}` in the template is replaced with a formatted value. The script stops if any placeholder is left unfilled.
- To change the README's wording, edit the template, never `README.md`.

## Dashboard: index.qmd

A static Quarto dashboard (`format: dashboard`). A setup chunk at the top runs the three SQL files against the database (read-only) and reads the CSVs in `outputs/`, `model/parameters.csv`, the reference targets in `data/reference/air_quality_targets.csv` and the boundaries. The value boxes, tables and charts are computed from these, and most chart titles are built with `sprintf()` from the data, so they rewrite themselves if the data change. Figures in the explanatory text (thresholds, discount rates, the published hazard-ratio interval, the reference levels and the City of London's population) are also read from `model/parameters.csv`, `data/reference/air_quality_targets.csv` or the outputs rather than typed in. Dates and the names of sources are written as text.

| Page | What is on it | Where the numbers come from |
|---|---|---|
| Overview | Value boxes: London PM2.5 in 2024 (8.9 µg/m³), deaths at 30+ attributable (6.6%), break-even £116.3m a year. Trend chart of London against England with WHO (5 µg/m³) and England target (10 µg/m³) lines, and a table | SQL 02; `results_london.csv`; the reference targets file |
| Boroughs | Map of PM2.5 by area; ranked bar chart of attributable %, from 6.1% (Bromley) to 7.3% (Tower Hamlets); searchable table of all 33 areas | SQL 01; boundaries |
| Deprivation | Scatter of IMD 2025 against PM2.5 (r = 0.65, 32 boroughs); table of thirds; a note that this compares areas, not people | SQL 01 for the scatter, Pearson correlation in R; SQL 03 for the table |
| Respiratory admissions | Scatters of PM2.5 against asthma admissions under 19 (r = 0.06, no clear association) and COPD admissions 35+ (r = 0.38, moderate); a note that this is descriptive only | SQL 01, correlations in R |
| What a 1 µg/m³ cut is worth | Value boxes: 82,670 QALYs, £116.3m a year, £12.75 per resident with its PSA interval. Borough table (10, 20, 30 years at £20,000; 20 years at £30,000; per resident; PSA interval). Horizon table in both views. Tornado. Acceptability curve. Every parameter with its source | `results_*.csv`, `breakeven.csv`, `breakeven_temporary_cut.csv`, `psa_summary.csv`, `tornado.csv`, `comparisons.csv`, `acceptability.csv`, `psa_hr_check.csv`, `parameters.csv` |
| Methods and sources | Method in plain English, limitations, data sources | Inline R pulls the hazard ratio, lag shares, ages, discount rate and horizon from `parameters.csv`, and the hazard multiplier and life expectancy check from `model_checks.csv` |

The City of London is shown on the map and in the tables, marked "small population", and left out of rankings and correlations. The verbal strength of a correlation in a title ("no clear" below 0.1, "weak" below 0.3, "moderate" below 0.5, otherwise "strong") comes from a small rule in the setup chunk, not from hand-written text.

### Chart conventions (R/dashboard_helpers.R)

- One accent colour for the series the chart is about, grey for context.
- A title that states the finding, built from the data.
- A source line and alt text on each chart. The borough values behind the map and the scatters are also in the searchable table on the Boroughs page, and the trend chart has a table beside it.
- Checked with screenshots at desktop (1366 px) and phone (390 px) widths, as recorded in the commit messages.

### Page weight: the basic plotly bundle

Every plotly chart goes through `plotly_defaults()`, which calls `partial_bundle(type = "basic", local = TRUE)`. The basic plotly.js bundle covers scatter, line and bar charts, which is all the dashboard uses (the map is leaflet, not plotly). It is 0.99 MB (0.33 MB gzipped), against 3.6 MB (1.1 MB gzipped) for the full library. The whole page, meaning `index.html` plus every script, stylesheet, font and image it loads, is 1.05 MB gzipped.

### docs/ and GitHub Pages

- `_quarto.yml` sets `output-dir: docs`, so `quarto render` writes the site to `docs/`. GitHub Pages can serve it from the `docs/` folder on the main branch.
- The dashboard's JavaScript and CSS libraries in `docs/index_files/` are committed, so the published page does not depend on a render on GitHub.
- Quarto's working files (`.quarto/`, and `index_files/` at the project root) are ignored by git.
- Not yet published: that waits for Lassi's go-ahead.

## Independent checks

| Check | What was done | What it changed |
|---|---|---|
| Re-implementation | A separate agent wrote the model in Python from a written specification only, without seeing the R code. A second reviewer wrote a loop-based R version | Both matched: the Python version in all nine scenarios (discounted QALYs to 12 significant figures), the loop version to 1e-14. Nothing needed fixing (D23) |
| Code review | Read the R code for bugs | Found one: the 30+ populations were missing from the results files (the `summarise()` order described under R/05). Fixed, with a regression test |
| Methods review | Reviewed the model's design, assumptions and citations | The changes recorded as D14 and D17 to D22, listed below |
| Source verification | AI agents downloaded the primary documents and recorded quotes with page numbers; a second agent re-checked each | The quotes are in `notes/verified_sources.md`, which was used to fill the sources in `model/parameters.csv` |

These checks do not replace Lassi reading the code and re-checking the key sources in person (see the last section).

What the methods review changed:
- **D14:** corrected a citation. PMG20's 1.5% applies to costs and health; the Green Book's 1.5% is for health only. There are now three discount scenarios, each with its own source.
- **D17:** the horizon had become the biggest driver of the annual figure, so the "cut lasts only while it is paid for" view was added. On that view the annual figure barely depends on the horizon.
- **D18:** the open-cohort scenario was added, and the notes say plainly that the base case counts fewer people than COMEAP's method.
- **D19:** the lag runs in calendar time for everyone. Restarting it at age 30 for entrants would change the open-cohort total by under 0.5%.
- **D20:** costs and health are both discounted from the end of year 1, so the annual break-even does not depend on the convention.
- **D21:** NHS and social care savings from PHE (2018) are not added, because that report describes its scenario inconsistently. Stated as a limitation instead.
- **D22:** the tornado holds only uncertain inputs and model choices. EQ-5D-3L and the temporary cut moved to comparisons, and the factor-of-two rule was added.

## Before an interview

- Read `R/model_functions.R` alongside the "model in one block" above, then `sql/01` to `03` alongside their CTE tables.
- Run `Rscript R/run_all.R` and `quarto render` once yourself, and open `outputs/results_london.csv` and `outputs/tornado.csv`.
- Re-check the key sources in the original documents: COMEAP 2022 for the hazard ratio (p.8, para 31) and the lag (p.11, para 40); NICE PMG20 Box 7.2 for £20,000 per QALY and section 7.7 for discounting; NICE PMG51 for EQ-5D-5L; Green Book 2026 para 6.58 for the 1.5% health rate; Defra's air quality appraisal guidance (section 5.3) for £84,548.
- Re-check the discount rates after the Budget on 28 October 2026. The cut in the standard rate from 3.5% to 3% was announced on 7 September 2026, and further changes are expected at the Budget (D14, `notes/verified_sources.md`).
- Be ready to say plainly that an AI coding assistant wrote the code and AI agents checked the sources, and what you decided yourself.
- Rehearse the likely questions in `notes/interview_prep.md`.
