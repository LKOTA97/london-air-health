# London air pollution and health

What is a sustained 1 µg/m³ reduction in annual mean PM2.5 worth in each London borough, in quality-adjusted life years (QALYs)? And how much could a borough spend each year to achieve it while staying cost-effective?

This project answers that with open data from OHID Fingertips and the Office for National Statistics, a DuckDB database queried with SQL, a life-table model in R, and a Quarto dashboard.

Work in progress. Findings will appear here once the model runs; every number will come from the code outputs.

## Status

Session 1
- [x] Environment and `renv`
- [ ] Data downloads with manifest
- [ ] DuckDB build and data tests
- [ ] SQL: latest values by borough and trends
- [ ] Dashboard skeleton with the Overview page

Session 2
- [ ] Life-table model and deterministic results
- [ ] Model tests
- [ ] `model/parameters.csv` complete
- [ ] Decision log

Session 3
- [ ] One-way sensitivity analysis and PSA
- [ ] Remaining dashboard pages
- [ ] README findings
- [ ] Published on GitHub Pages
- [ ] Notes: walkthrough, interview prep, SQL practice

## Licences

Code: MIT (see `LICENSE`). Data keeps its original licence. Contains public sector information licensed under the Open Government Licence v3.0.

## Author

Personal project by Lassi Kotamäki. Views are my own.
