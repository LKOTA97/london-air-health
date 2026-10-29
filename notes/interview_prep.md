# Interview preparation

Fifteen questions I expect in interviews for UKHSA, DHSC and London borough public health analyst and health economist roles, with short answers grounded in this project. An AI coding assistant drafted this note from the repository. The answers are written in my voice, but they are drafts to rehearse in my own words, not scripts to recite.

Every number comes from `outputs/`, from running the queries in `sql/` against `data/london_air.duckdb`, from the source files in `notes/` and `model/`, or was computed from those with R in this repository (marked as computed), as they stood on 27 October 2026. If the model is re-run, check the figures against the "Numbers to know" table at the end. The Green Book discount rates may change at the Budget on 28 October 2026, so check that before any interview after that date.

---

## 1. Why a hazard ratio of 1.08, and why no cut-off?

Because that is what COMEAP, the Committee on the Medical Effects of Air Pollutants, recommends. Its 2022 statement (p.8, para 31) recommends 1.08 per 10 µg/m³, with a 95% interval of 1.06 to 1.09, from Chen and Hoek's 2020 review. The statement calls it a summary effect estimate; COMEAP's 2023 summary labels it RR, and the model applies it to the death rate as a hazard ratio. On the cut-off, para 50(iii) says it does not recommend one and suggests quantifying to zero, assuming the relationship stays linear on the log scale. COMEAP reaffirmed linearity in October 2025.

Using the same coefficient as the official statistic matters too. Fingertips indicator 93861, the share of deaths attributable to PM2.5, is built from 1.08. A data test in the project checks this for every London area and year from 2018 to 2024: the largest difference from the formula with 1.08 is 0.00004 percentage points, while with 1.07 or 1.09 the largest difference is more than one percentage point.

In practice a cut-off would not change this result. COMEAP's optional sensitivity cut-off is 3 µg/m³, and the cleanest borough, Bromley, was at 8.13 µg/m³ in 2024. A 1 µg/m³ cut multiplies the death rate at every age in the model (30 and over) by about 0.9923 once fully in effect. One caveat: it is a single-pollutant estimate, not adjusted for other pollutants.

## 2. Why a closed cohort by default?

The base case follows the 5.55 million residents aged 30 and over in mid-2025 to age 100, with no one joining. My brief specified it, and it has two advantages: it is conservative, and it needs no projection of births or migration, which would be uncertain in London. It also matches the evidence: COMEAP's 2010 report applied the lower hazard from age 30 because the original study cohort was adults aged 30 and over.

But it differs from COMEAP's own practice, which follows the whole current population for 106 years, so that today's children benefit once they reach 30. The project says so plainly and runs an open-cohort scenario that adds residents who turn 30 in years 2 to 20. That raises London's break-even from £116.3m to £144.7m a year, 1.24 times the base. The lag runs in calendar time for everyone, so someone who turns 30 in year 10 has breathed cleaner air since year 1.

## 3. What is the biggest limitation?

It counts deaths only. Long-term PM2.5 also causes illness, affects children, and costs the NHS and social care, and none of that is in the model, so on balance the break-even is probably too low. One thing pulls the other way: extra years are valued at average population quality of life, and the people whose deaths are delayed are more likely to have heart or lung disease, so their quality of life may be lower.

A second, practical limitation is that the model values a hypothetical 1 µg/m³ cut across a whole borough. It says nothing about what any real scheme achieves, and for most schemes that exposure change is the weakest input. That is also why the output is framed as a break-even budget, not the value of a scheme.

If asked for more: England death rates in every borough (the SMR scenario moves London's figure by about 1%), nobody moves house, and the PSA covers the hazard ratio only.

## 4. Why does the annual break-even depend on the horizon?

The model gives one present value: 82,670 discounted QALYs times £20,000, about £1.65bn in today's money. To turn that into a yearly budget it is divided by an annuity factor at 3.5%: 8.32 for 10 years, 14.21 for 20 and 18.39 for 30. So the same sum is £198.8m a year over 10 years, £116.3m over 20 and £89.9m over 30. That is a factor of 2.21, the largest in the tornado.

That reading assumes H years of spending buy a cut that then lasts, like rebuilt streets. A methods review pointed out that this lets a presentation choice drive the answer, so the project also reports a second view: the cut lasts only while it is paid for, then fades on the same lag. Now a longer horizon buys more QALYs as well as spreading the cost (26,638, 48,470 and 64,792 discounted QALYs over 10, 20 and 30 years), and the annual figure barely moves: £64.1m, £68.2m and £70.5m.

I would use the first view for capital schemes with lasting effects and the second for schemes with running costs, such as enforcement.

## 5. Which threshold applies to a council, and why?

There is no single right answer, so the project shows several and says what each one means.

- **£20,000 per QALY (base case).** NICE's guidelines manual, PMG20, covers public health. Box 7.2 says interventions under £20,000 per QALY are "generally considered to be cost effective", and gives no explicit £30,000. My brief used £25,000; the base case moved to £20,000 once the sources were checked.
- **£25,000 to £35,000.** In use since spring 2026, but for technology appraisals only. NICE's FAQ says the change "only applies to medicines and health technologies evaluated through a Technology Appraisal". Shown for comparison: £145.4m and £203.6m a year.
- **The council's own opportunity cost.** What a council gives up is whatever else its public health grant would buy, not the NHS's marginal QALY, and I have no published figure for it. PMG20 section 7.7 says the usual perspective for public health is the public sector, which "may be simplified to a local government perspective if few costs and effects apply to other government agencies".
- **Green Book societal value.** Defra's £84,548 per QALY (2025 prices) is a willingness-to-pay value for cost-benefit analysis, not an opportunity cost. With Green Book conventions as revised in the Budget of 28 October 2026 (spending and health discounted at 3% for the first 30 years, health values uprated by 2% a year), it gives £1,074.0m a year over 20 years. Under the old rules (health at 1.5%, spending at 3.5%) it was £905.9m.

Break-even is proportional to the threshold, so anyone can rescale the headline.

## 6. Walk me through the join in `02_trends.sql`.

The query stacks borough, London and England rows for 2018 to 2024. The join that matters builds the London row.

1. `air_quality` pivots the two Fingertips indicators into one row per area and year: `MAX(CASE WHEN indicator_id = 93867 THEN value END)` for PM2.5, and the same for 93861.
2. `population_total` sums the population table to one row per area and year. The population table has 182 rows per area and year (two sexes, single years of age 0 to 89 plus 90 and over), so summing first keeps the join one-to-one.
3. `london_rows` inner-joins the two on **both** `area_code` and `year`, so 2018 values are weighted by 2018 population, and computes `SUM(value * population) / SUM(population)` grouped by year.

The inner join also filters. The population table holds only the 33 London areas, so the England and London-region rows drop out without a `WHERE` clause.

A subtle point: this weighted mean would come out the same with the unsummed table, because the age rows add up to the total. But the join would fan out from 33 to 6,006 rows a year, and any `COUNT` or unweighted `SUM` of the indicator values would then be 182 times too large. Summing first makes the grain explicit. As a check, the weighted mean is within 0.02 µg/m³ of Fingertips' own London figure every year; a simple average of the 33 areas is up to 0.07 away.

> **Note for Lassi (not part of the answer):** An AI coding assistant wrote this query; it was originally planned as your own task. If the interviewer assumes you wrote it, say so. Practise writing it yourself from the spec in `notes/sql_tasks.md`.

## 7. What does the PSA add, and what are its limits?

It puts an interval around the headline from the hazard ratio, the key input with a published confidence interval. The PSA draws 5,000 values of log(HR) from a normal distribution centred on log(1.08), with a standard error derived from the published interval: (log(1.09) minus log(1.06)) divided by 2 times 1.96. London's break-even has a median of £116.3m a year and a 95% interval of £95.5m to £137.2m, or £10.47 to £15.04 per resident.

The acceptability curve turns that into a decision rule. At £20,000 per QALY, a scheme costing up to £10.80 per resident a year is cost-effective in at least 95% of draws, and up to £12.70 in at least half.

The limits matter as much. It varies the hazard ratio only; utilities, life tables and population are fixed, so the interval reflects that uncertainty alone. The two largest swings in the tornado are structural choices, the horizon and the discount rates, and they sit in the one-way analysis, not the PSA. Also, the published interval is slightly asymmetric on the log scale, so the drawn 2.5th and 97.5th percentiles are 1.065 and 1.095, not 1.06 and 1.09. That is why the PSA interval sits a little above the one-way range of £88.1m to £130.3m.

## 8. How would you use this to appraise a specific Healthy Streets scheme?

As a screen, not as the appraisal itself.

1. **Exposure change.** Estimate the scheme's change in population-weighted annual mean PM2.5 for the residents affected, from air quality modelling or monitoring. This is the weakest number, and it is likely to be small, because much of London's PM2.5 is regional rather than from local traffic.
2. **Re-run the model** with that change and the affected population's age structure (small-area population estimates if the scheme covers part of a borough). For small changes the effect is close to linear. For example, a hypothetical 0.1 µg/m³ cut across Lambeth gives 273 discounted QALYs, about £385,000 a year over 20 years at £20,000 per QALY, against £3.84m for a full 1 µg/m³.
3. **Match the view to the costs.** Street redesign is mostly capital with lasting effects, so use the lasting-cut view. Enforcement or anything with running costs needs the cut-lasts-while-paid-for view.
4. **Compare** with the scheme's own costs, discounted the same way.
5. **Add what the model leaves out.** For an active travel scheme that includes physical activity, road injuries, noise, NO2 and illness, which may well matter more than the PM2.5 effect and need their own methods.
6. **Look at who benefits**, since more deprived boroughs tend to have higher PM2.5.

> **Note for Lassi (not part of the answer):** the 0.1 µg/m³ Lambeth example is not in `outputs/`. It was computed for this note by running `borough_gains()` from `R/model_functions.R` with `delta = 0.1`. Re-run it yourself before quoting it.

## 9. Did you use AI tools?

Yes, a lot, and the README says so. I chose the question and wrote a detailed project brief: the data sources, the model design, the SQL tasks, the dashboard pages and the writing rules. I decided to use IMD 2025 instead of IMD 2019, and then asked an AI coding assistant to complete the remaining work.

An AI coding assistant wrote all of the code (the R scripts, the model, the tests and the dashboard) and the notes. It also wrote the three SQL queries and the deprivation chart, which I had originally planned to write myself. AI agents checked the sources: they downloaded the primary documents (COMEAP, NICE, the Green Book, the legislation, ONS, EEPRU), recorded quotes with page numbers, and a second agent re-checked each one.

Checking was built in. An independent re-implementation of the model in Python by a separate AI agent, written from a specification only, matched the R model in all nine scenarios. A code review found one bug, missing 30+ populations in the two results files, which was fixed with a regression test. A methods review led to several changes, including the second break-even view and correcting how the discount-rate scenarios were sourced.

Several later method choices, such as the £20,000 threshold and the EQ-5D-5L norms, began as proposals from the source checks and the methods review, and were put in place when I asked the AI coding assistant to complete the work. They are all recorded in the decision log. My part was the question and the brief; my job now is to understand every choice well enough to explain and defend every number.

> **Note for Lassi (not part of the answer):** only say you reviewed or checked something if you actually have. You did not do the re-implementation, the code review or the methods review yourself; say so if asked. Before interviews, read `R/model_functions.R`, `R/05_model.R`, `R/06_sensitivity.R` and the three SQL files, run them, and re-check the key sources yourself: COMEAP 2022 p.8 para 31 and p.13 para 50(iii), PMG20 Box 7.2 and section 7.7, the NICE FAQ on thresholds, and PMG51. Once you have done that, you can truthfully add "I have since read the code and re-checked the key sources myself." Practise writing the SQL from the specs in `notes/sql_tasks.md`, since analyst interviews may include a live SQL test.

## 10. Why EQ-5D-5L, and what changes with 3L?

NICE's interim methods statement PMG51 (27 August 2026) makes the UK EQ-5D-5L value set the preferred approach for topics starting after that date, including for population norms and for NICE guidelines, which cover public health. So the base case uses the new 5L norms from Hernández Alava and Wailoo's EEPRU Report 082 (2026), based on the Health Survey for England 2017 and 2018. My brief had the older 3L norms from the NICE DSU 2022 report.

5L norms are higher, especially at older ages: 0.814 against 0.738 for men at 90. With 3L, London's discounted QALYs fall from 82,670 to 75,695, and the break-even from £116.3m to £106.5m a year, about 8% lower.

The project reports 3L as a comparison with the pre-2026 method, not in the tornado, because a different value set is a method choice, not an uncertainty. Strictly, PMG51 says 3L values may not be used even in scenarios, so in a NICE submission I would drop it; here it shows how much the method change matters. Utilities are fixed in the PSA because the sources give parameter covariances, not standard errors, for the predicted means.

## 11. Why do borough results differ only by population and age structure?

Two features of the method. COMEAP's relationship is log-linear with no threshold, so a 1 µg/m³ cut multiplies the death rate by the same 0.9923 whether a borough starts at 9.81 µg/m³ (Tower Hamlets) or 8.13 (Bromley). And the base case uses England death rates everywhere. So a borough's result depends only on how many residents it has and their age and sex.

Croydon gains most in total, 3,872 discounted QALYs, because it has the most residents aged 30 and over. Per resident, the figure runs from £10.52 a year in Tower Hamlets to £14.39 in Richmond upon Thames. It tracks the share of residents aged 30 and over: 52% in Tower Hamlets against 67% in Richmond, with a correlation of 0.99 across the 32 boroughs.

That surprises people, because Tower Hamlets has the highest PM2.5 of the 32 boroughs. Under this model the value of a further cut does not depend on the starting level. Scaling death rates by each borough's SMR changes London's total by about 1%: lower mortality means fewer deaths delayed, but more life-years for each one, and the two largely cancel.

## 12. How did you validate the model?

- **Against ONS.** The model's own survival calculation gives life expectancy at 30 of 50.28 years for men and 53.87 for women, against ONS's 50.28 and 53.90.
- **Against the official statistic.** Fingertips 93861 equals `100 * (1 - 1.08^(-C/10))` for every London area and year from 2018 to 2024 to within 0.00004 percentage points; with 1.07 or 1.09 the largest gap is more than one percentage point. That ties the coefficient to what OHID publishes.
- **Behaviour tests.** A hazard ratio of 1 gives zero gain; a 2 µg/m³ cut gives about twice the gain (within 2%); QALYs are below life-years; the London total equals the sum of boroughs; scenarios move in the expected direction.
- **Independent re-implementation.** A separate AI agent wrote the model in Python from a written specification only, without seeing the R code, and matched all nine scenarios (discounted QALYs to 12 significant figures). A loop-based R version by a second reviewer matched to 1e-14.
- **Code review.** It found one bug, missing 30+ populations in a results file, now fixed and covered by a regression test.

The SQL is tested against values calculated separately in R. The tests were also run against two deliberate mistakes (a plain average for London, and ranking the City of London), and both mistakes made them fail.

## 13. What does the deprivation correlation show, and what does it not show?

Across the 32 boroughs (City of London left out), the IMD 2025 score and 2024 PM2.5 have a correlation of 0.65. Split into thirds by IMD (11, 11 and 10 boroughs), mean PM2.5 is 8.45 µg/m³ in the least deprived third, 9.09 in the middle and 9.21 in the most deprived.

It shows that more deprived boroughs tend to have higher PM2.5, which is relevant to an environmental inequalities argument. It does not show that deprived people breathe dirtier air: it is ecological, comparing areas, and there is a lot of variation inside each borough. It is also tangled with geography: inner London boroughs sit where traffic and the urban background are highest, and many of them are also more deprived. With only 32 areas, the estimate is imprecise: a standard Pearson test gives a 95% confidence interval of 0.38 to 0.81. IMD is a relative ranking, so it does not say how much more deprived one borough is than another.

None of this feeds the model: every borough gets the same per-person effect. To answer the question properly I would use small-area data, Defra's 1 km modelled concentrations against LSOA-level deprivation.

## 14. What would you do with more time?

1. **Illness.** Add morbidity outcomes as QALY losses avoided, and children's health.
2. **NHS and social care savings.** PHE (2018), Table 9, gives £2.35m per 100,000 people per 1 µg/m³ for Lambeth over 2015 to 2035, at 1.5% discounting and 2015 prices. The report describes its scenario inconsistently ("in 2017 only" in places, sustained elsewhere), so I would resolve that, then reprice and rediscount before adding it.
3. **Whole-population cohort.** Follow the whole current population, as COMEAP does over 106 years, so that today's children count once they reach 30. Births could be added after that.
4. **Migration.** London's population turns over quickly; the model assumes nobody moves.
5. **Scheme costs.** Take two or three real schemes with published costs and exposure estimates and test them against the break-even.
6. **Discounting.** Done on 29 October 2026, the day after the Budget. The revised Green Book cuts the standard rate to 3% for the first 30 years and replaces the 1.5% health discount rate with 2% a year uprating of health values. The Green Book scenario now gives £254.1m a year, up from £214.3m, and the base case (NICE's 3.5%) is unchanged. The open question is whether NICE follows the Green Book cut; a flat 3% scenario for costs and health gives £128.4m.

## 15. How would you explain the result to a director of public health in two sentences?

"If London cut fine particle pollution by 1 µg/m³ and kept it there, the people aged 30 and over who live here now would gain about 83,000 quality-adjusted life years in today's terms (after discounting), so at NICE's £20,000 per QALY we could spend up to £116m a year for 20 years, about £12.75 per resident a year, and still be good value. For Lambeth that is £3.8m a year, so a scheme costing less than that a year for each 1 µg/m³ it delivers is good value on avoided deaths alone, before counting illness or NHS savings."

> **Note for Lassi:** swap in the director's own borough from `outputs/results_borough.csv` (column `annual_breakeven`).

---

## Numbers to know

Base case unless stated: closed cohort aged 30+, HR 1.08, EQ-5D-5L, 3.5% discounting, £20,000 per QALY, 20-year horizon.

| What | Figure | Where it comes from |
|---|---|---|
| London population-weighted PM2.5, 2018 and 2024 | 12.25 and 8.90 µg/m³ | `sql/02_trends.sql` |
| England PM2.5, 2024 | 7.06 µg/m³ | `sql/02_trends.sql` |
| Deaths at 30+ attributable to PM2.5, 2024 | London 6.62% (population-weighted mean of the 33 areas), England 5.29% | `sql/02_trends.sql` |
| Highest and lowest borough PM2.5, 2024 | Tower Hamlets 9.81, Bromley 8.13 µg/m³ (City of London 10.96, not ranked) | `sql/01_borough_latest.sql` |
| IMD 2025 against PM2.5, 32 boroughs | correlation 0.65 (95% CI 0.38 to 0.81) | computed from `sql/01_borough_latest.sql` output |
| Mean PM2.5 by deprivation third (least to most deprived; 11, 11 and 10 boroughs) | 8.45, 9.09, 9.21 µg/m³ | `sql/03_deprivation_groups.sql` |
| Hazard multiplier for a 1 µg/m³ cut | 0.9923 | `outputs/model_checks.csv` |
| Residents, mid-2025: all ages and 30+ | 9,122,909 and 5,551,776 | `outputs/results_london.csv` |
| Discounted QALYs, London | 82,670 | `outputs/results_london.csv` |
| Undiscounted life-years; days per resident aged 30+ | 318,407; 20.9 days | `outputs/results_london.csv` |
| Break-even present value | £1,653m | `outputs/results_london.csv` |
| Annual break-even | £116.3m a year, £12.75 per resident | `outputs/results_london.csv` |
| Lasting cut over 10 and 30 years | £198.8m and £89.9m a year (factor 2.21) | `outputs/oneway.csv`, `outputs/tornado.csv` |
| Annuity factors at 3.5%, 10, 20 and 30 years | 8.32, 14.21, 18.39 | `outputs/annuity_factors.csv` |
| Cut lasts only while paid for, 10, 20 and 30 years | £64.1m, £68.2m, £70.5m a year | `outputs/breakeven_temporary_cut.csv` |
| £25,000, £30,000 and £35,000 per QALY | £145.4m, £174.5m, £203.6m a year | `outputs/breakeven.csv` |
| Societal value (£84,548, Green Book October 2026 discounting) | £1,074.0m a year | `outputs/breakeven.csv` |
| HR 1.06 and 1.09 | £88.1m and £130.3m a year | `outputs/oneway.csv` |
| Discount scenarios: NICE 1.5% both; Green Book October 2026 (3% falling after year 30, health uprated 2% a year); flat 3% both | £177.4m, £254.1m, £128.4m a year | `outputs/oneway.csv` |
| Open cohort | £144.7m a year (1.24 times) | `outputs/oneway.csv` |
| Life-years not QALYs; no lag; borough SMR | £143.5m; £130.9m; £114.9m a year | `outputs/oneway.csv` |
| EQ-5D-3L instead of 5L | 75,695 QALYs; £106.5m a year | `outputs/comparisons.csv` |
| PSA, London | median £116.3m; 95% interval £95.5m to £137.2m (£10.47 to £15.04 per resident) | `outputs/psa_summary.csv` |
| Acceptability at £20,000 | up to £10.80 per resident a year in 95% of draws; £12.70 in half | `outputs/acceptability.csv` |
| Per resident by borough | Tower Hamlets £10.52 to Richmond upon Thames £14.39 | `outputs/results_borough.csv` |
| Per resident against share aged 30+ | correlation 0.99 (Tower Hamlets 52%, Richmond 67%) | computed from `outputs/results_borough.csv` |
| Largest borough total | Croydon, 3,872 QALYs, £5.45m a year | `outputs/results_borough.csv` |
| Lambeth | £3.84m a year | `outputs/results_borough.csv` |
| Life expectancy at 30, model against ONS | men 50.28 against 50.28; women 53.87 against 53.90 | `outputs/model_checks.csv` |

## Sources to know

From `notes/verified_sources.md`. Know the page or paragraph for the first four.

- **COMEAP statement (2022, published 16 March 2022).** HR 1.08 (95% CI 1.06 to 1.09) per 10 µg/m³, p.8 para 31; no cut-off, quantify to zero, p.13 para 50(iii); US EPA cessation lag, p.11 para 40; 106-year follow-up, p.11 para 42. Linearity reaffirmed in October 2025.
- **NICE PMG20 (guidelines manual, covers public health).** £20,000 per QALY, Box 7.2 (section 7.8); public sector perspective and 3.5% discounting with 1.5% sensitivity analyses "particularly for public health guidance", section 7.7.
- **NICE thresholds for technology appraisals.** £25,000 to £35,000 since spring 2026 (NICE news, 2 April 2026; PMG36 section 6.3); SI 2026/202 gives the power for technology appraisals and highly specialised technologies only; the NICE FAQ confirms it does not yet cover other guidance.
- **NICE PMG51 (27 August 2026).** EQ-5D-5L value set preferred, including for population norms and NICE guidelines. Norms: Hernández Alava and Wailoo, EEPRU Report 082 (2026).
- **COMEAP (2010).** Hazards applied from age 30 (section 3.1.2, p.31); the "sustained reduction ... by 1 µg/m3" framing (section 4.1, p.38). COMEAP's separate 2010 lag paper, Table 17, p.52: 1.33% a year in years 6 to 20.
- **Green Book (2026, updated 28 October 2026).** 3.00% for years 1 to 30, 2.50% for 31 to 75, 2.25% from 76 (para 6.54). Health values uprated by 2% a year (para 8.58), replacing the 1.5% health discount rate (HM Treasury response, Box 1.A). QALY value £70,000 in 2020-21 prices (para 8.57). This follows the Discount Rate Review (30 June 2026), whose 3% rate HM Treasury accepted (para 2.36).
- **Defra air quality appraisal, impact pathways (28 April 2026).** £84,548 per QALY in 2025 prices, section 5.3.
- **Targets.** WHO guideline 5 µg/m³ (2021). Legal target of 10 µg/m³ by the end of 2040 at every relevant monitoring station, and a 35% cut in population exposure against 2016 to 2018 (SI 2023/96, regs 4, 5 and 7). Interim target of 10 µg/m³ by December 2030 (Environmental Improvement Plan 2025, Commitment 21, p.41).
- **PHE (2018), Table 9, p.30.** NHS and social care costs avoided per 1 µg/m³ per 100,000 people: £2.35m for Lambeth over 2015 to 2035 (1.5% discounting, 2015 prices), with the scenario wording caveat.
- **Fingertips 93861 metadata.** "a relative risk (RR) of 1.08 per 10 µg/m3 (COMEAP, 2022)", the same coefficient as the model.
