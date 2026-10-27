# Checks on the life-table model (brief section 8.3, plus a few structural ones).

source(here::here("R/model_functions.R"))
params   <- read_parameters()
inputs   <- load_model_inputs(params)
settings <- base_settings(params)
base     <- borough_gains(inputs, settings, params)

london <- function(results, col = "qaly_gained_disc") sum(results[[col]])
with_settings <- function(...) modifyList(settings, list(...))

test_that("the hazard multiplier for a 1 ug/m3 cut is about 0.9923", {
  expect_equal(hazard_multiplier(1.08, 1), 0.9923, tolerance = 1e-4)
})

test_that("the cessation lag reaches 30%, 42.5%, 80% and 100% in years 1, 2, 5 and 20", {
  expect_equal(lag_share(c(1, 2, 5, 20, 40), params), c(0.30, 0.425, 0.80, 1, 1))
  expect_true(all(diff(lag_share(1:25, params)) >= 0))
  expect_equal(lag_share(1:3, params, lag = FALSE), c(1, 1, 1))
})

test_that("life expectancy at 30 is within 0.5 years of the ONS figure for each sex", {
  for (s in c("Female", "Male")) {
    lt <- inputs$life_table[inputs$life_table$sex == s, ]
    model <- life_expectancy(30, setNames(lt$mx, lt$age), 100)
    expect_lt(abs(model - lt$ex[lt$age == 30]), 0.5)
  }
})

test_that("splitting the 90+ group keeps the population total", {
  split <- split_90_plus(inputs$population, inputs$life_table, 100)
  expect_equal(sum(split$population), sum(inputs$population$population))
  expect_equal(max(split$age), 100)
})

test_that("HR = 1 gives zero QALYs gained", {
  none <- borough_gains(inputs, with_settings(hr = 1), params)
  expect_equal(london(none, "qaly_gained"), 0)
  expect_equal(london(none, "ly_gained"), 0)
})

test_that("a 2 ug/m3 cut gives about twice the gain of a 1 ug/m3 cut (within 2%)", {
  double <- borough_gains(inputs, with_settings(delta = 2), params)
  ratio <- london(double) / london(base)
  expect_lt(abs(ratio - 2), 0.04)
})

test_that("QALYs gained are less than life-years gained", {
  expect_true(all(base$qaly_gained < base$ly_gained))
  expect_true(all(base$qaly_gained_disc < base$ly_gained_disc))
})

test_that("discounted gains are less than undiscounted gains", {
  expect_true(all(base$qaly_gained_disc < base$qaly_gained))
  expect_true(all(base$ly_gained_disc < base$ly_gained))
})

test_that("gains are positive for every borough", {
  expect_equal(nrow(base), 33)
  expect_true(all(base$qaly_gained_disc > 0))
})

test_that("the London total equals the sum of the boroughs in the saved outputs", {
  boroughs <- readr::read_csv(here::here("outputs", "results_borough.csv"), show_col_types = FALSE)
  total    <- readr::read_csv(here::here("outputs", "results_london.csv"), show_col_types = FALSE)
  for (col in c("ly_gained", "ly_gained_disc", "qaly_gained", "qaly_gained_disc", "annual_breakeven")) {
    expect_equal(total[[col]], sum(boroughs[[col]]), tolerance = 1e-10)
  }
  expect_equal(total$population, sum(inputs$population$population))
})

test_that("scenarios move the result in the expected direction", {
  expect_gt(london(borough_gains(inputs, with_settings(lag = FALSE), params)), london(base))
  expect_gt(london(borough_gains(inputs, with_settings(cohort = "open"), params)), london(base))
  expect_gt(london(borough_gains(inputs, with_settings(r_health = 0.015), params)), london(base))
  expect_gt(london(borough_gains(inputs, with_settings(hr = 1.09), params)), london(base))
  expect_lt(london(borough_gains(inputs, with_settings(hr = 1.06), params)), london(base))
})

test_that("break-even annual spend is the present value divided by the annuity factor", {
  expect_equal(annuity_factor(20, 0.035), (1 - 1.035^-20) / 0.035)
  expect_equal(breakeven_annual(100, 20000, 20, 0.035), 100 * 20000 / annuity_factor(20, 0.035))
  # The annual figure falls as the horizon lengthens
  expect_gt(breakeven_annual(100, 20000, 10, 0.035), breakeven_annual(100, 20000, 30, 0.035))
})

test_that("saved results have no missing values and 30+ populations add up", {
  boroughs <- readr::read_csv(here::here("outputs", "results_borough.csv"), show_col_types = FALSE)
  total    <- readr::read_csv(here::here("outputs", "results_london.csv"), show_col_types = FALSE)
  expect_false(anyNA(boroughs))
  expect_false(anyNA(total))
  pop30 <- sum(inputs$population$population[inputs$population$age >= 30])
  expect_equal(total$population_30plus, pop30)
  expect_true(all(boroughs$population_30plus < boroughs$population))
})

test_that("a cut that ends fades on the same lag and gains less than a permanent cut", {
  expect_equal(lag_share(c(1, 20, 21, 22, 40), params, cut_years = 20), c(0.30, 1, 0.70, 0.575, 0))
  expect_equal(lag_share(c(1, 20, 21), params, lag = FALSE, cut_years = 20), c(1, 1, 0))
  temporary <- borough_gains(inputs, with_settings(cut_years = 20), params)
  expect_lt(london(temporary), london(base))
  expect_equal(london(borough_gains(inputs, with_settings(cut_years = Inf), params)), london(base))
})

test_that("the societal value uses Green Book discounting and the NICE thresholds do not", {
  b <- readr::read_csv(here::here("outputs", "breakeven.csv"), show_col_types = FALSE)
  london_rows <- b[b$area_code == "LONDON" & b$horizon == 20, ]
  nice <- london_rows$health_gain_disc[london_rows$threshold_name == "nice_guidelines"]
  societal <- london_rows$health_gain_disc[london_rows$threshold_name == "societal"]
  expect_equal(nice, london(base))
  expect_gt(societal, nice)
})
