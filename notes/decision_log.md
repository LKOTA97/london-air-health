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
- **Reason:** a very small population (15,631 in mid-2025, against 145,734 in Kensington and Chelsea, the next smallest; about 8,000 to 9,000 in 2018 to 2021, which is where the brief's "about 9,000" came from), so rates are unstable. Its PM2.5 was the highest in London every year from 2021 to 2024 (10.96 µg/m³ in 2024), so it would top the recent rankings. Newham was highest in 2018 to 2020.
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

## D7. EQ-5D-3L norms from the NICE DSU 2022 report (superseded as base case by D12)

- **Choice so far:** Hernández Alava, Pudney and Wailoo (NICE DSU, 12 January 2022). We use the spreadsheet sheet "Expected EQ-5D-3L", which has single years of age 16 to 101 by sex. The report recommends these HSE 2014 values (section 6).
- **Checks:** the spreadsheet matches Table 1 of the report (page 19) at ages 30, 50 and 70 for both sexes, and at 90 for males. For females at 90, Table 1 shows 0.672 but the spreadsheet gives 0.6655; 0.672 is the spreadsheet's age-89 value. This is probably a one-row slip in the printed table, worth 0.007 at one age.
- **Uncertainty:** the report's appendix (page 23) gives coefficients and standard errors for the mixture model, and the spreadsheet gives covariance matrices. The brief's rule is to draw utilities in the PSA if the source gives standard errors, so this needs a decision in session 3.
- **Licence:** the spreadsheet has no open licence. It is downloaded but not committed; only the tidy values are, with the citation.
- **Outcome:** confirmed that NICE PMG51 (27 August 2026) moved to EQ-5D-5L, so these 3L norms are now a comparison only (D12).

## D8. Deprivation measure: IMD 2025

- **Options:** IMD 2019 (indicator 93553, as in the original brief) or IMD 2025 (indicator 94240, on Fingertips since 25 November 2025).
- **Choice:** IMD 2025, decided by Lassi on 27 October 2026. Used for `imd_score` in `sql/01_borough_latest.sql`, the deprivation thirds in `sql/03_deprivation_groups.sql` and the Deprivation page. IMD 2019 stays in the database for reference only.
- **Reason:** it is the current official measure of deprivation in England, and the newest data matches the rest of the project (mid-2025 population, 2024 PM2.5).
- **Caveat:** the Fingertips metadata says IMD 2025 "is not directly comparable" with IMD 2019. It has 55 indicators against 39, with 20 new and 14 significantly modified. This does not matter here because we use one snapshot, not a change over time. Like IMD 2019, it is a relative measure: it ranks areas but does not say by how much one is more deprived than another.
- **Source:** Fingertips metadata for 94240, "Notes" and "Caveats" fields (`data/raw/fingertips_metadata.csv`). Technical report: https://www.gov.uk/government/publications/english-indices-of-deprivation-2025-technical-report

## D9. Borough mortality scenario: SMR indicator 93250 (decided 27 October 2026)

- **Options:**
  - 93250: SMR, all ages, deaths 2019 to 2023 pooled, England = 100, persons only.
  - 93823: directly standardised rate, all ages, single years to 2025 and three-year pools. The City is combined with Hackney.
- **Choice:** 93250, because an SMR is calculated from England's age-specific rates, which is exactly what scaling England's life table needs. Borough mx = England mx x SMR/100 at every age and for both sexes.
- **Result:** London's break-even falls by about 1%. Lower mortality means fewer deaths delayed each year, but more life-years for each death delayed, and the two largely cancel.
- **Caveat:** its period includes the Covid years 2020 and 2021.

## D10. Database format readable by older DuckDB tools

- **Choice:** write `london_air.duckdb` with `storage_compatibility_version = "v1.2.0"`.
- **Reason:** the R package (DuckDB 2.0.0) writes a format that the DuckDB command-line tool on winget (1.5.6) cannot open. Checked by opening the rebuilt file with DuckDB 1.5.6.

## D11. Validation: Fingertips 93861 uses HR 1.08 with no cut-off

- **Finding:** for every London area and year from 2018 to 2024, 93861 equals `100 * (1 - 1.08^(-C/10))` to within 4e-5, where C is 93867. With 1.07 or 1.09 the gap exceeds 1 percentage point.
- **Source:** the Fingertips metadata for 93861 states "a relative risk (RR) of 1.08 per 10 µg/m3 (COMEAP, 2022)" and AF = 100*(RR-1)/RR. This ties the model's coefficient to the official statistic.

---

The entries below began as proposals and were **implemented on 27 October 2026**, after Lassi asked for the remaining work to be completed. Each can be reversed by changing `model/parameters.csv` or the settings in `R/model_functions.R`.

## D12. EQ-5D version: EQ-5D-5L base case (implemented)

- **Options:**
  - 3L norms: NICE DSU 2022, HSE 2014, already in the database.
  - 5L norms: Hernández Alava and Wailoo 2026, EEPRU Report 082, HSE 2017 and 2018, UK 5L value set.
- **What changed:** NICE PMG51 (27 August 2026) makes 5L the preferred approach for topics starting after that date, including NICE guidelines and so public health. It points to the EEPRU 5L norms.
- **Choice:** 5L norms as the base case. Our question is a new analysis, and 5L is NICE's current method. 3L is reported only as a comparison with the pre-2026 method (outputs/comparisons.csv: 106.5m a year against 116.3m), not in the tornado, because a different value set is a method choice, not an uncertainty.
- **PSA:** utilities held fixed. Uncertainty from a survey of over 14,000 people is second-order next to the hazard ratio, and the sources give parameter covariances, not standard errors, for the predicted means.
- **Effect:** 5L values are higher, especially at older ages (age 90: 0.814 against 0.738 for men), so QALYs will rise.
- **Licence:** the 5L report is CC BY 4.0, but the spreadsheet has no licence statement, so treat it like the DSU file: download, do not redistribute.

## D13. Thresholds: £20,000 per QALY base (implemented)

- **Facts:**
  - NICE guidelines, including public health, state £20,000 per QALY (PMG20 Box 7.2) and give no explicit £30,000.
  - £25,000 to £35,000 applies only to technology appraisals (NICE FAQ, SI 2026/202).
- **Choice:**
  - £20,000 per QALY is the base threshold for the headline, tornado and PSA. This differs from the £25,000 in the brief because NICE's public health methods (PMG20) still state £20,000.
  - Tables also show £30,000 (NICE's previous upper bound, cited to NICE's 1 December 2025 announcement), £25,000 and £35,000 (technology appraisals only), and the societal value.
  - Annual break-even is proportional to the threshold, so the tornado's shape is the same at any threshold.

## D14. Discount rates: 3.5% base, three scenarios (implemented; re-check after the Budget on 28 October 2026)

- **Facts:**
  - NICE: 3.5% for costs and health (PMG20, PMG36). PMG20 suggests 1.5% sensitivity analyses "particularly for public health guidance".
  - Green Book 2026: 3.5% standard and 1.5% for health.
  - The Discount Rate Review (June 2026) recommends 3% for everything, including health. The government has announced the cut to 3%.
- **Choice:** 3.5% for costs and health (NICE). Three scenarios, each with its own source:
  - NICE PMG20: 1.5% for both costs and health (177.4m a year).
  - Green Book: 1.5% for health, 3.5% for costs (214.3m).
  - Discount Rate Review: 3.0% for both.
- **Correction:** an earlier draft cited PMG20 for the Green Book version. PMG20's 1.5% applies to both costs and health; the independent methods review caught this.

## D15. Societal value of a QALY: £84,548, Green Book conventions (implemented)

- **Facts:** the Green Book 2026 states no figure. Defra's air quality appraisal guidance (updated April 2026) gives £84,548 per QALY in 2025 prices, "in accordance with the Green Book".
- **Choice:** £84,548 (2025 prices), applied with Green Book conventions throughout: QALYs discounted at 1.5%, spending at 3.5%. It is a cost-benefit value, labelled separately from the NICE cost-effectiveness thresholds.

## D16. Cessation lag year by year (implemented)

- **Fact:** COMEAP 2022 (para 40) uses the US EPA lag, with years 6 to 20 "with smoothed annual values". COMEAP's 2010 lag paper (Table 17) gives 1.33% a year for years 6 to 20.
- **Proposal:**
  - Year 1: 30%.
  - Years 2 to 5: 12.5% each.
  - Years 6 to 20: 20/15 = 1.333% each.
  - Cumulative share: 30, 42.5, 55, 67.5, 80 ... 100% at year 20.

## D17. Break-even framing: a lasting cut, plus a "cut lasts only while paid for" view

- **Problem (from the independent methods review):** the present value counts a permanent cut, but the spend is spread over H years. So the horizon, a presentation choice, became the biggest driver of the annual figure (a factor of 2.2 between 10 and 30 years).
- **Choice:**
  - The headline keeps the brief's framing, stated as an assumption: H years of spending buy a cut that then lasts, as with infrastructure.
  - Added the alternative where the cut lasts only while it is paid for and then fades on the same lag, as lag(t) - lag(t - H). This follows because the US EPA lag is a response to each year's change in concentration, so ending the cut is a second change of the opposite sign.
  - On that view the annual break-even barely depends on H: 64.1m, 68.2m and 70.5m a year over 10, 20 and 30 years at £20,000 per QALY.
- **Why both:** schemes with lasting effects (street redesign) and schemes needing running costs (enforcement) fit different views.

## D18. Population: residents aged 30+ (base) and an open-cohort scenario

- **Fact:** COMEAP's practice follows the whole current population for 106 years, so under-30s benefit once they reach 30.
- **Choice:** keep current residents aged 30 and over as the conservative base case, as the brief specifies, and say plainly that this differs from COMEAP. The open-cohort scenario adds residents turning 30 in years 2 to 20 (aged 11 to 29 in 2025) and gives 144.7m a year (1.24 times the base). There are no births or in-migration.

## D19. The lag runs in calendar time for everyone

- **Choice:** the cumulative lag share depends on years since the cut began, for the closed cohort and for open-cohort entrants alike. Entrants have breathed the lower concentration since year 1.
- **Check:** restarting the lag at age 30 would change the open-cohort total by under 0.5% (methods review).

## D20. Discounting from the end of year 1 for both costs and health

- **Choice:** the discount factor in year t is 1/(1+r)^t for QALYs and for spending, matching the brief's annualisation formula.
- **Effect:** because the convention is shared, the annual break-even does not depend on it. Reported discounted QALYs are about 3.5% lower than if year 1 were undiscounted.

## D21. NHS and social care savings not added (optional version 2)

- **Fact:** PHE (2018), Table 9, gives NHS and social care costs avoided per 1 µg/m³ per 100,000 people: £2.35m for Lambeth over 2015 to 2035, at 1.5% discounting and 2015 prices.
- **Choice:** not added. The report describes its 1 µg/m³ scenario inconsistently ("in 2017 only" in places, while the detailed outputs look sustained). Its discounting and price year also differ from ours. Stated as a limitation instead.

## D22. Tornado holds uncertain inputs and model choices; comparisons sit apart

- **Choice:** the tornado keeps the inputs the brief lists: HR, lag, discount rates, cohort, QALYs against life-years, SMR, horizon. EQ-5D-3L and the cut-lasts-while-paid-for view go to `outputs/comparisons.csv`, because they answer a different question rather than measuring uncertainty.
- **Factor-of-two rule:** only the horizon crosses it (2.21), so every borough's result is shown across 10, 20 and 30 years.

## D23. Model checked by independent re-implementation

- **What:** a separate agent wrote the model in Python from a written specification only, without seeing the R code. It matched all nine scenarios: discounted QALYs to 12 significant figures. A loop-based R version by a second reviewer matched to 1e-14.
- **Bug found:** the code review found one bug, empty 30+ populations in the results files. It was fixed, and a regression test was added.
