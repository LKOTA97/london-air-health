# Decision log

One entry per modelling or data choice: the options, the choice, the reason and the source. Newest entries at the bottom. Entries marked **open** need a decision.

---

## D1. Geography: upper-tier local authorities, 33 London areas

- **Options:** lower-tier (area type 501) or upper-tier (502) local authorities.
- **Choice:** Fingertips area type 502, "Upper tier local authorities (post 4/23)", keeping area codes starting E09 plus England.
- **Reason:** in London the two tiers are the same 33 areas. 502 is the type the brief specifies and the one every indicator we need is published at.
- **Source:** `https://fingertips.phe.org.uk/api/area_types` (checked 27 October 2026). Data files label these rows "Counties & UAs (from Apr 2023)".

## D2. City of London: kept, flagged, left out of rankings and correlations

- **Options:** drop it, merge it with Hackney, or keep it and flag it.
- **Choice:** keep it in every table with `is_city_of_london = true`. Leave it out of rankings and correlations, and say so on the dashboard.
- **Reason:** about 9,000 residents, so rates are unstable. Its PM2.5 (10.96 µg/m³ in 2024) is the highest in London and would top any ranking.
- **Extra fact found:** for asthma (90810) and COPD (92302) admissions, Fingertips combines the City with Hackney. The City's value is blank, and Hackney's carries the note "Value for Hackney and City of London combined".
- **Source:** Fingertips metadata, "Disclosure control" field for 90810 and 92302 (`data/raw/fingertips_metadata.csv`).

## D3. Population: Nomis NM_2002_1, mid-2018 to mid-2025

- **Options:** only the latest year, or every year from 2018.
- **Choice:** every year from 2018 to 2025, by single year of age (0 to 89, plus 90 and over) and sex.
- **Reason:** mid-2025 is the latest (Nomis updated 29 July 2026) and is used for the model. The earlier years let the 2018 to 2024 London trend weight each year by that year's population.
- **Check:** each year's borough sum equals the Nomis London region total exactly.
- **Source:** `https://www.nomisweb.co.uk/api/v01/dataset/NM_2002_1.def.sdmx.json`. Geography type TYPE423 is "local authorities: county / unitary (as of April 2023)".

## D4. London trend: population-weighted mean of the 33 areas

- **Options:** a simple average of boroughs, a population-weighted mean, or the official Fingertips London region figure.
- **Choice:** a population-weighted mean calculated in SQL, using total population (all ages) for both PM2.5 and the attributable fraction. The Fingertips London figure is used only as a check.
- **Reason:** a weighted mean is the right summary of exposure across residents, and calculating it shows the method.
- **Check:** it is within 0.02 µg/m³ of the official figure every year, while a simple average is up to 0.07 away.
- **Caveat:** weighting the attributable fraction by all-ages population rather than by deaths at 30+ is a simplification. The result matches the official London attributable fraction to within 0.02 percentage points.

## D5. Raw data saved as text, exactly as received

- **Choice:** every Fingertips and Nomis column is read and written as text, so numbers are not reformatted. Raw files are committed, and `data/raw/MANIFEST.csv` records URL, time and row count.
- **Reason:** reproducibility if the APIs change. Re-running the download gave byte-identical files.

## D6. Life table: ONS National life tables, England, 2022 to 2024

- **Choice:** the England reference tables released 10 December 2025, latest period 2022 to 2024, ages 0 to 100.
- **Reason:** latest available. The next edition (2023 to 2025) has no confirmed date: the workbook says "Next publication: to be confirmed".
- **Check value for the model test:** ONS life expectancy at 30 is 50.28 years (males) and 53.90 (females), from sheet "2022-2024", column ex.
- **Source:** `https://www.ons.gov.uk/peoplepopulationandcommunity/birthsdeathsandmarriages/lifeexpectancies/datasets/nationallifetablesenglandreferencetables`

## D7. EQ-5D norms: NICE DSU 2022, HSE 2014, EQ-5D-3L (open)

- **Choice so far:** Hernández Alava, Pudney and Wailoo (NICE DSU, 12 January 2022). We use the spreadsheet sheet "Expected EQ-5D-3L", which has single years of age 16 to 101 by sex. The report recommends these HSE 2014 values (section 6).
- **Checks:** the spreadsheet matches Table 1 of the report (page 19) at ages 30, 50 and 70 for both sexes, and at 90 for males. For females at 90, Table 1 shows 0.672 but the spreadsheet gives 0.6655; 0.672 is the spreadsheet's age-89 value. This is probably a one-row slip in the printed table, worth 0.007 at one age.
- **Uncertainty:** the report's appendix (page 23) gives coefficients and standard errors for the mixture model, and the spreadsheet gives covariance matrices. The brief's rule is to draw utilities in the PSA if the source gives standard errors, so this needs a decision in session 3.
- **Licence:** the spreadsheet has no open licence. It is downloaded but not committed; only the tidy values are, with the citation.
- **Open:** NICE may have moved to EQ-5D-5L general-population norms in 2026 (PMG51). Being verified.

## D8. Deprivation measure: IMD 2025

- **Options:** IMD 2019 (indicator 93553, as in the original brief) or IMD 2025 (indicator 94240, on Fingertips since 25 November 2025).
- **Choice:** IMD 2025, decided by Lassi on 27 October 2026. Used for `imd_score` in `sql/01_borough_latest.sql`, the deprivation thirds in `sql/03_deprivation_groups.sql` and the Deprivation page. IMD 2019 stays in the database for reference only.
- **Reason:** it is the current official measure of deprivation in England, and the newest data matches the rest of the project (mid-2025 population, 2024 PM2.5).
- **Caveat:** the Fingertips metadata says IMD 2025 "is not directly comparable" with IMD 2019. It has 55 indicators against 39, with 20 new and 14 significantly modified. This does not matter here because we use one snapshot, not a change over time. Like IMD 2019, it is a relative measure: it ranks areas but does not say by how much one is more deprived than another.
- **Source:** Fingertips metadata for 94240, "Notes" and "Caveats" fields (`data/raw/fingertips_metadata.csv`). Technical report: https://www.gov.uk/government/publications/english-indices-of-deprivation-2025-technical-report

## D9. Borough mortality scenario: which all-cause indicator (open, session 2)

- **Options:**
  - 93250: SMR, all ages, deaths 2019 to 2023 pooled, England = 100, persons only.
  - 93823: directly standardised rate, all ages, single years to 2025 and three-year pools. The City is combined with Hackney.
- **Leaning:** 93250, because an SMR is calculated from England's age-specific rates, which is exactly what scaling England's life table needs.
- **Caveat:** its period includes the Covid years 2020 and 2021.

## D10. Database format readable by older DuckDB tools

- **Choice:** write `london_air.duckdb` with `storage_compatibility_version = "v1.2.0"`.
- **Reason:** the R package (DuckDB 2.0.0) writes a format that the DuckDB command-line tool on winget (1.5.6) cannot open. Checked by opening the rebuilt file with DuckDB 1.5.6.

## D11. Validation: Fingertips 93861 uses HR 1.08 with no cut-off

- **Finding:** for every London area and year from 2018 to 2024, 93861 equals `100 * (1 - 1.08^(-C/10))` to within 4e-5, where C is 93867. With 1.07 or 1.09 the gap exceeds 1 percentage point.
- **Source:** the Fingertips metadata for 93861 states "a relative risk (RR) of 1.08 per 10 µg/m3 (COMEAP, 2022)" and AF = 100*(RR-1)/RR. This ties the model's coefficient to the official statistic.
