# Verified sources

Facts the project relies on, checked on **27 October 2026** against the primary documents. Each was downloaded and read, then independently re-checked by a second reader trying to refute it. Everything here was upheld unless marked otherwise. Use this file to fill `model/parameters.csv` (session 2) and the README sources section.

## What changed since the project brief

| Brief said | Now | Source |
|---|---|---|
| Interim target 12 µg/m³ by January 2028 | **Replaced** by 10 µg/m³ by December 2030 | Environmental Improvement Plan 2025, Commitment 21, p.41 |
| £25,000 to £35,000 per QALY "confirmed for technology appraisals from April 2026"; unclear for public health | In force since March to April 2026 for **technology appraisals only**. NICE guidelines, including public health, still state £20,000 per QALY | NICE FAQ; PMG20 Box 7.2 |
| UK EQ-5D norms from the NICE DSU 2022 report (EQ-5D-3L) | NICE now prefers **EQ-5D-5L** (PMG51, 27 August 2026), including for population norms and for NICE guidelines | NICE PMG51 |
| Green Book health discount rate 1.5% | Still 1.5% today, but a **cut to the standard rate (3.5% to 3%) has been announced**, with changes due at the **Budget on 28 October 2026** | Green Book 2026; Discount Rate Review 2026 |
| Green Book QALY value about £70,000 | The Green Book itself no longer states one. Latest government figure: **£84,548 in 2025 prices** (Defra, April 2026, "in accordance with the Green Book") | Defra impact pathways guidance |
| Life tables: latest three-year period | 2022 to 2024 (released 10 December 2025) | ONS |
| Population: mid-2023 or mid-2024 | Mid-2025 (Nomis updated 29 July 2026) | Nomis |
| IMD 2019 | IMD 2025 now on Fingertips (94240), chosen by Lassi | Fingertips |

## Air quality reference values

- **WHO global air quality guidelines 2021**
  - Annual PM2.5 guideline: **5 µg/m³**. Interim targets: 35, 25, 15, 10.
  - Location: section 3.2.2.1 and Table 3.1, printed p.78.
  - Link: https://iris.who.int/handle/10665/345329
- **SI 2023/96, Environmental Targets (Fine Particulate Matter) (England) Regulations 2023**
  - Reg. 4: "by the end of 31st December 2040 the annual mean level of PM2.5 in ambient air must be equal to or less than 10 µg/m³".
  - Reg. 5: met if the target holds at **every relevant monitoring station**, rounded to a whole number. So it is not an area average.
  - Reg. 7: at least a 35% reduction in population exposure by the end of 2040, against the average for 2016 to 2018.
  - No amendments as of 27 October 2026.
  - Link: https://www.legislation.gov.uk/uksi/2023/96/regulation/4
- **Environmental Improvement Plan 2023**
  - Interim targets: 12 µg/m³ and a 22% exposure reduction by the end of January 2028 (p.77).
  - **Replaced by EIP 2025.**
  - Link: https://assets.publishing.service.gov.uk/media/64a6d9c1c531eb000c64fffa/environmental-improvement-plan-2023.pdf
- **Environmental Improvement Plan 2025** (published 1 December 2025)
  - Commitment 21, p.41: "an annual mean concentration target of 10 micrograms per cubic metre to be achieved by December 2030" and "a population exposure reduction target of 30% compared to 2018 to be achieved by December 2030".
  - Restates the 2040 legal targets unchanged.
  - Link: https://assets.publishing.service.gov.uk/media/692d8d9cce50d215cae962a5/Environmental_Improvement_Plan__EIP__2025.pdf
- **Air Quality Standards Regulations 2010, Schedule 2**
  - PM2.5 annual limit value **20 µg/m³** from 1 January 2020.
  - Link: https://www.legislation.gov.uk/uksi/2010/1001/schedule/2

## COMEAP

- **Statement** signed "COMEAP, January 2022"; published on GOV.UK by UKHSA on **16 March 2022**.
  - PDF: https://assets.publishing.service.gov.uk/media/623302158fa8f504aa780865/COMEAP_Statement_on_PM2.5_mortality_quantification.pdf
  - Landing page: https://www.gov.uk/government/publications/particulate-air-pollution-quantifying-effects-on-mortality
- **Coefficient**
  - Wording (p.8, para 31): "we recommend adoption of the summary effects estimate of **1.08 (95% CI: 1.06, 1.09) per 10 µg/m3** annual average PM2.5 drawn from Chen and Hoek's (2020) global evidence base". It is not adjusted for other pollutants.
  - The 2022 statement does not call it a hazard ratio or a relative risk. COMEAP's 2023 summary labels it "RR" (p.14): https://assets.publishing.service.gov.uk/media/64fadfdea78c5f0014265847/COMEAP_Quantification_recommendations.pdf
- **No cut-off** (p.13, para 50(iii))
  - Wording: "We do not recommend the use of a cut-off value for quantification. We suggest quantification to zero PM2.5, using an assumption of continuing linearity."
  - Footnote 1 defines linearity as linearity on the log scale.
  - Optional sensitivity cut-off: 3 µg/m³, the lowest 5th percentile among the studies.
- **Linearity reaffirmed** in October 2025, with a recommendation to run sensitivity analyses across the 95% CI.
  - Link: https://www.gov.uk/government/publications/comeap-shape-of-the-concentration-response-curve-linking-pm25-with-all-cause-mortality
- **Cessation lag** (p.11, para 40)
  - Uses the US EPA lag: 30% of the risk reduction in year 1, 50% across years 2 to 5 (12.5% a year), and 20% across years 6 to 20 "with smoothed annual values".
  - COMEAP's 2010 lag paper (Table 17, p.52) puts years 6 to 20 at 1.33% a year, giving cumulative 30, 43, 55, 68, 80 ... 100% by year 20.
  - Link: https://assets.publishing.service.gov.uk/media/5a75871ded915d6faf2b3af6/COMEAP_development_of_proposals_for_cessation_lags.pdf
- **106-year follow-up** (p.11, para 42 and footnote 12)
  - Wording: "It is common practice to use a follow-up period of 106 years which is a period long enough to allow the current population to die out."
- **Ages 30 and over**
  - Not stated in the 2022 statement. COMEAP (2010), section 3.1.2, p.31 applied reduced hazards from age 30 because the original cohort was adults aged 30 and over.
  - The same report frames its main question as "a sustained reduction ... by 1 µg/m3 PM2.5" (section 4.1, p.38).
  - Link: https://assets.publishing.service.gov.uk/media/5a7e2f4640f0b62302689b57/COMEAP_mortality_effects_of_long_term_exposure.pdf
- **Fingertips 93861** uses "a relative risk (RR) of 1.08 per 10 µg/m3 (COMEAP, 2022)" with AF = 100(RR−1)/RR, applied to the whole concentration. The project's validation test confirms this for every London area and year.

## NICE thresholds and methods

- **1 December 2025** news: new thresholds of £25,000 to £35,000 per QALY for technology appraisals, applied once NICE has the power.
  - Link: https://www.nice.org.uk/news/articles/changes-to-nice-s-cost-effectiveness-thresholds-confirmed
- **SI 2026/202**: made 2 March 2026, in force 24 March 2026.
  - It gives the Secretary of State a power to direct NICE on the threshold for technology appraisals and highly specialised technologies only. The SI itself does not set the figures.
  - Link: https://www.legislation.gov.uk/uksi/2026/202/made
- **2 April 2026** news: the new thresholds are in use for technology appraisals.
  - Link: https://www.nice.org.uk/news/articles/changes-to-nice-s-cost-effectiveness-thresholds-take-effect
- **Scope** (NICE FAQ): "At this stage, the threshold change only applies to medicines and health technologies evaluated through a Technology Appraisal. We await further detail from government on whether this will be extended to cover all NICE guidance in the future."
  - Link: https://www.nice.org.uk/what-nice-does/faqs/changes-to-nice-s-cost-effectiveness-thresholds
- **PMG36** (technology appraisal manual)
  - Section 6.3 now uses £25,000 and £35,000.
  - 4.5.1: 3.5% discounting for costs and health.
  - 4.5.3: 1.5% only when all three criteria are met.
  - Link: https://www.nice.org.uk/process/pmg36/chapter/economic-evaluation-2
- **PMG20** (NICE guidelines manual, which covers public health). Link: https://www.nice.org.uk/process/pmg20/chapter/incorporating-economic-evaluation
  - Threshold, Box 7.2, section 7.8: "Interventions with an ICER of less than £20,000 per QALY gained are generally considered to be cost effective." No explicit £30,000.
  - Perspective, section 7.7: "The usual perspective for the economic analysis of public health interventions is that of the public sector. This may be simplified to a local government perspective if few costs and effects apply to other government agencies."
  - Discounting, section 7.7: 3.5% for costs and health. "Sensitivity analyses using 1.5% ... may be presented ... particularly for public health guidance."
  - No equity weighting.

## Green Book and the value of a QALY

- **The Green Book (2026)**, updated 5 February 2026. Links: https://www.gov.uk/government/publications/the-green-book--2 and PDF https://assets.publishing.service.gov.uk/media/698dbcd17da91680ad7f4308/The_Green_Book_2026.pdf
  - Para 6.54: 3.5% for years 1 to 30, 3.0% for 31 to 75, 2.5% from year 76.
  - Para 6.58: health and life effects "should be discounted at a lower rate of 1.5%".
- **Discounting supplementary guidance** (February 2026), Table 3.A: the health rate is 1.5% (years 1 to 30), 1.286% (31 to 75) and 1.071% (76 to 125).
  - This conflicts with Green Book para 6.58, which says 1.5% "applies in every year". Resolve before modelling past 30 years.
  - Link: https://assets.publishing.service.gov.uk/media/698f30a4492ea446ea7f43d3/Green_Book_supplementary_guidance_-_discounting.pdf
- **Green Book Discount Rate Review** (Freeman and Groom, 30 June 2026) recommends 3% for up to 30 years, used "for all projects, including health", which drops the separate 1.5% health rate.
  - The government announced the cut from 3.5% to 3% on 7 September 2026. A news story of 22 October 2026 says further reforms come "at next week's Budget" (28 October 2026). **Re-check after the Budget.**
  - Link: https://www.gov.uk/government/publications/green-book-discount-rate-review-2026
- **QALY value**
  - The Green Book 2026 (para 8.57) points to "supplementary guidance on health", which is a 2013 page with no current figure.
  - The Wellbeing guidance (July 2021, Annex 2, p.55) gives "£60,000 as per HMT Green Book guidance (2014 prices and values), or £70,158 in 2019 prices and values". Link: https://assets.publishing.service.gov.uk/media/60fa9169d3bf7f0448719daf/Wellbeing_guidance_for_appraisal_-_supplementary_Green_Book_guidance.pdf
  - **Latest:** Defra air quality appraisal, impact pathways approach (updated 28 April 2026), section 5.3: "In accordance with the Green Book the Willingness to Pay (WTP) for a QALY is **£84,548 in 2025 prices**." Link: https://www.gov.uk/government/publications/assess-air-quality-impacts/air-quality-appraisal-impact-pathways-approach
  - Defra values a life year lost to chronic air pollution at £59,200 (2025 prices) and discounts health at 1.5%.
- **GDP deflators** (HM Treasury, 1 October 2026, base 2025-26 = 100) for any price-year uprating. A new version is due after the Budget.
  - Link: https://www.gov.uk/government/statistics/gdp-deflators-at-market-prices-and-money-gdp-september-2026-quarterly-national-accounts

## EQ-5D

- **NICE DSU 2022** (EQ-5D-3L, HSE 2014). In use now; see decision D7.
  - Its page now carries an "Update April 2026" note pointing to new 5L estimates.
  - Link: https://sheffield.ac.uk/nice-dsu/methods-development/estimating-eq-5d
- **NICE PMG51**, "Interim methods statement: implementing the EQ-5D-5L value set" (27 August 2026).
  - Use the UK EQ-5D-5L value set (Rowen et al. 2026) for all adult reference-case utilities. 3L values may not be used even in scenarios.
  - Use 5L for general-population norms.
  - Applies to topics starting after 27 August 2026, including **NICE guidelines** (it amends PMG20).
  - Replaces ECD16.
  - FAQ 15 points to the EEPRU page for 5L age and sex norms.
  - Link: https://www.nice.org.uk/process/pmg51
- **New 5L norms:** Hernández Alava M, Wailoo A. EQ-5D-5L age adjustment estimates using the health survey for England. EEPRU Report 082, April 2026.
  - Report DOI: 10.15131/shef.data.31889488, licensed CC BY 4.0. The report is the PDF only.
  - Data: HSE 2017 and 2018, single years 16 to 101 by sex. Respondents aged 90 and over were coded as 92, so values above 92 are extrapolated.
  - Uncertainty: parameter covariance matrices, but no standard errors on the predicted means.
  - The spreadsheet is on Google Drive and has no licence statement.
  - Example values, male / female: age 30 0.935 / 0.912; 50 0.899 / 0.884; 70 0.856 / 0.835; 90 0.814 / 0.759.
  - Link: https://eepru.sites.sheffield.ac.uk/current-projects/theme-2-measuring-and-valuing-outcomes/eq-5d-5l-adoption
- **Value set:** Rowen D, Mukuria C, Bray N, et al. A United Kingdom Value Set for the EQ-5D-5L. *Value in Health* 2026;29(5):858-869. doi:10.1016/j.jval.2026.03.008.

## PHE 2018 NHS and social care costs (optional version 2)

- **Report:** "Estimation of costs to the NHS and social care due to the health impacts of air pollution", published 22 May 2018. Nothing has superseded it.
  - Link: https://www.gov.uk/government/publications/air-pollution-a-tool-to-estimate-healthcare-costs
- **Table 9, p.30:** NHS and social care costs avoided from a 1 µg/m³ PM2.5 reduction, per 100,000 people, over 2015 to 2035:
  - England £2.42m; Lambeth (inner London) £2.35m; South Lakeland £2.05m.
  - Discounted at 1.5%, in 2015 prices.
  - Covers diseases with stronger and weaker evidence.
- **Caveat:** the report's text calls the reduction "in 2017 only" in places, while the detailed outputs look like a sustained cut. Resolve this before using the figures.
- **Usable for borough savings:** yes, by applying the per-100,000 figures to borough populations, with stated assumptions. The local authority tool itself cannot model a 1 µg/m³ change.
