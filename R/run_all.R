# run_all.R
# Runs the whole pipeline in order, then the tests.
# From the project folder: Rscript R/run_all.R

steps <- c(
  "R/01_get_fingertips.R",
  "R/02_get_ons.R",
  "R/03_get_other.R",
  "R/04_build_db.R",
  "R/05_model.R",
  "R/06_sensitivity.R",
  "R/07_write_readme.R"
)

for (step in steps) {
  message("\n=== ", step, " ===")
  source(here::here(step), local = new.env())
}

message("\n=== tests ===")
testthat::test_dir(here::here("tests", "testthat"), reporter = "summary", stop_on_failure = TRUE)
