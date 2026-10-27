# Walkthrough

Every script and query in the order they run, what each does, and why it is built that way. Read this before an interview. The decision log (`notes/decision_log.md`) has the reasons for individual data and modelling choices.

## How the pieces fit

```
R/01 to 03   download raw data   ->  data/raw/ (+ MANIFEST.csv)
R/04         tidy and load       ->  data/clean/*.csv and data/london_air.duckdb
sql/01, 02   query the database  ->  read by the dashboard
R/05, 06     model (session 2)   ->  outputs/
tests/       check data, SQL and model
index.qmd    Quarto dashboard    ->  reads the database and outputs/
```

Run everything with `Rscript R/run_all.R`. It runs 01 to 04 and then all the tests.

## Environment

- **renv** records every package version in `renv.lock`, so `renv::restore()` rebuilds the same library on any machine.
- Packages come from a dated Posit Package Manager snapshot (26 October 2026, set in `.Rprofile`). Every machine gets the same versions, and Windows gets ready-built binaries, so it needs no compiler (Rtools).
- `DESCRIPTION` lists the packages the project uses, and renv snapshots from it (`snapshot.type = "explicit"`). This keeps dashboard-only packages such as leaflet in the lockfile even before any code uses them.

## R/00_setup.R

Loaded at the top of every script. It sets:
- the packages,
- the folder paths, built with `here()` so they work from any working directory on Windows or Linux,
- the Fingertips indicator IDs,
- `options(timeout = 300)`, because ONS files can take more than R's default 60 seconds,
- two helpers: `download_to()` retries a download up to three times; `record_download()` adds or replaces the file's row in `data/raw/MANIFEST.csv`.

## R/01_get_fingertips.R

Downloads eight indicators from the OHID Fingertips API at upper-tier local authority level (area type 502). It keeps the 33 London areas (codes starting E09) and England.

- Every column is read as text and written straight back. Converting to numbers and back can change how a value is written, and the raw folder should hold exactly what the API sent.
- It also saves the indicator metadata. That file is the evidence for how each indicator is calculated, including the COMEAP coefficient behind 93861.
- It saves Fingertips' own London region values for PM2.5 and the attributable fraction. They are only used to check our population-weighted London mean.

Things found while building it:
- The England rows appear twice in each file (once with England as its own "parent"). Step 04 removes the duplicate.
- For asthma and COPD admissions the City of London has no value of its own. Hackney's value covers both.

## R/02_get_ons.R

**Population.** Gets mid-year population by single year of age and sex from Nomis dataset NM_2002_1.
- Geography `2013265927TYPE423` means "every county or unitary authority (April 2023 boundaries) inside the London region".
- Nomis returns at most 25,000 rows per request, so it asks for one year at a time.
- It stops with an error unless each year has 33 areas, 91 ages, and a borough sum equal to the Nomis London total.

**Life tables.** Downloads the ONS National life tables for England (released 10 December 2025, latest period 2022 to 2024). The file is pinned because its name changes with each edition.

## R/03_get_other.R

- **EQ-5D-3L by age and sex.** The NICE DSU spreadsheet (Hernández Alava, Pudney and Wailoo, 2022). It is an old-format `.xls` file, despite how the website labels it. It has no open licence, so git ignores the original and only the tidy values are committed.
- **Borough boundaries.** Local Authority Districts (May 2026), ultra-generalised. The query asks the ONS server for E09 codes only, already in WGS84 coordinates for leaflet. The file is 25 KB, so it needs no further simplification for phones.

## R/04_build_db.R

Turns the raw files into five tidy tables, writes them to `data/clean/` as CSV, and loads them into DuckDB.

| Table | One row per |
|---|---|
| indicators | area, indicator, period |
| areas | area (33 London areas, London region, England) |
| population | area, sex, single year of age, year |
| life_table | sex, age (England, 2022 to 2024) |
| utility_norms | sex, single year of age |

Key steps:
- Fingertips files hold several breakdowns per indicator (deprivation deciles, male, female, age bands). A small lookup table `keep_breakdown` names the one breakdown to keep for each indicator, and `semi_join` filters to it.
- `year_start` comes from Fingertips' sortable period field (YYYY0000). This handles "2018", "2023/24" and pooled periods like "2019 - 23" the same way.
- The life table sheet has males and females side by side. The script checks the header row says exactly `age, mx, qx, lx, dx, ex` before using it, so a layout change in a future ONS edition fails loudly instead of silently.
- The database is rebuilt from scratch every run. It is saved in a storage format that DuckDB 1.2 and later can read, so older DuckDB tools can open it.

## Tests: tests/testthat/test-data.R

| Check | Why |
|---|---|
| Every indicator has 33 London areas in its latest period | catches a dropped area |
| No duplicate area, indicator, period, sex and age | catches join or filter mistakes |
| PM2.5 between 3 and 20; attributable % between 2 and 12 | catches unit or parsing errors |
| **Validation:** 93861 = `100 * (1 - 1.08^(-C/10))` for every London area and year | ties the model's hazard ratio to the official statistic |
| City of London admissions blank, Hackney flagged | documents the combined values |
| Area codes agree across indicators, population and boundaries | joins will not silently lose an area |
| Population, life table and utilities complete | the model needs every age |

The validation test has teeth: the maximum difference is 0.00004 with 1.08, but more than 1 percentage point with 1.07 or 1.09.

## SQL: sql/01_borough_latest.sql and sql/02_trends.sql (Lassi writes)

The specs, expected outputs and hints are in `notes/sql_tasks.md`. `tests/testthat/test-sql.R` checks both files against values calculated independently in R. It was tested against two deliberate mistakes, a plain average and ranking the City of London, and both fail.

## Dashboard: index.qmd

- A Quarto dashboard (`format: dashboard`), static, so GitHub Pages can host it.
- It runs the SQL files directly against the database, so every number on the page comes from a query, not from typing.
- Charts follow one convention, set in `R/dashboard_helpers.R`:
  - one accent colour for the series the chart is about, grey for context;
  - a title that states the finding, built from the data;
  - a source line, alt text, and a table next to each chart.
- Checked with screenshots at desktop (1366 px) and phone (390 px) widths.
