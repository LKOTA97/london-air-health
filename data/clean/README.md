# Clean data

Built by `R/04_build_db.R` from the files in `data/raw/`. The same tables are loaded into `data/london_air.duckdb`.

| File | One row per | Source | Licence |
|---|---|---|---|
| `indicators.csv` | area, indicator, period | OHID Fingertips API, area type 502 (upper-tier local authorities from April 2023), plus London region values for indicators 93867 and 93861 | Open Government Licence v3.0 |
| `areas.csv` | area | Derived from the indicators | Open Government Licence v3.0 |
| `population.csv` | area, sex, single year of age, year | ONS mid-year population estimates via Nomis dataset NM_2002_1, mid-2018 to mid-2025 | Open Government Licence v3.0 |
| `life_table.csv` | sex, age | ONS National life tables, England, period 2022-2024, released 10 December 2025 | Open Government Licence v3.0 |
| `utility_norms.csv` | version, sex, single year of age | **EQ-5D-5L** (base case): Hernández Alava M, Wailoo A. EQ-5D-5L age adjustment estimates using the Health Survey for England. EEPRU Report 082, 2026, doi:10.15131/shef.data.31889488; supplementary spreadsheet, sheet "Predictions" (HSE 2017-18, UK 5L value set). **EQ-5D-3L** (scenario): Hernández Alava M, Pudney S, Wailoo A. Estimating EQ-5D by Age and Sex for the UK. NICE Decision Support Unit, 12 January 2022; spreadsheet sheet "Expected EQ-5D-3L" (HSE 2014) | Values reproduced with citation; neither original spreadsheet is redistributed here |
| `london_boundaries.geojson` | London area | ONS Open Geography Portal, Local Authority Districts (May 2026) Boundaries UK BUC | Open Government Licence v3.0. Contains OS data © Crown copyright and database right 2026 |

## Notes on the columns

- `indicators.year_start` is the first calendar year of the period: 2018 for "2018", 2023 for "2023/24", 2019 for the pooled period "2019 - 23".
- `indicators.value_note` keeps the Fingertips note. For asthma (90810) and COPD (92302) admissions the City of London has no value of its own: its value is blank and Hackney's value covers both areas.
- `indicators.indicator_key` is a short readable name for each indicator ID, set in `R/00_setup.R`.
- `areas.is_london` is true for the 33 London local authority areas (codes starting E09), which include the City of London. The London region row (E12000007) is false.
- `population.age` 90 means aged 90 and over.
- `life_table.ex` is the ONS period life expectancy at that age, kept to check the model.
- Indicator 93823 (all-cause mortality, directly standardised) has both single-year and three-year pooled periods.
