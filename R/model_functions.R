# model_functions.R
# Life-table model of a sustained cut in annual mean PM2.5.
# Functions only. Used by R/05_model.R, R/06_sensitivity.R and the model tests.
#
# How it works, in one paragraph:
# Each cohort is the residents of one sex and one single year of age. It is
# followed year by year to age 100. In each year the baseline death rate mx
# comes from the England life table (optionally scaled by the borough SMR).
# With the cut, mx is multiplied by 1 - lag(t) * (1 - HR^(-delta/10)), where
# lag(t) is the share of the full effect in force in calendar year t.
# Survival is exp(-cumulative mx) (the same as qx = 1 - exp(-mx) each year).
# Life-years use the mid-year approximation. QALYs weight each life-year by
# the age-sex EQ-5D norm. Gains are intervention minus baseline.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(readr)
})

# Parameters ---------------------------------------------------------------------

read_parameters <- function(path = here::here("model", "parameters.csv")) {
  p <- read_csv(path, col_types = cols(.default = col_character()))
  structure(set_names(as.list(p$value), p$name), table = p)
}

# Low or high value of a parameter's range, from the same file
param_bound <- function(params, name, bound = c("low", "high")) {
  bound <- match.arg(bound)
  table <- attr(params, "table")
  value <- suppressWarnings(as.numeric(table[[bound]][table$name == name]))
  if (length(value) != 1 || is.na(value)) stop("No ", bound, " value for parameter: ", name)
  value
}

param_num <- function(params, name) {
  if (is.null(params[[name]])) stop("Parameter not found in model/parameters.csv: ", name)
  value <- suppressWarnings(as.numeric(params[[name]]))
  if (is.na(value)) stop("Parameter is not numeric: ", name)
  value
}

# Base-case settings. Scenarios copy this list and change one or more entries.
base_settings <- function(params) {
  list(
    delta            = param_num(params, "delta_pm25"),
    hr               = param_num(params, "hr_per_10ugm3"),
    lag              = TRUE,
    r_health         = param_num(params, "discount_rate_health"),
    r_cost           = param_num(params, "discount_rate_costs"),
    cohort           = "closed",
    open_entry_years = param_num(params, "open_cohort_entry_years"),
    mortality        = "england",
    utility_version  = params$utility_version,
    outcome          = "qaly",
    age_min          = param_num(params, "age_min"),
    age_max          = param_num(params, "age_max"),
    population_year  = param_num(params, "population_year"),
    horizon          = param_num(params, "horizon_years")
  )
}

# Inputs -------------------------------------------------------------------------

load_model_inputs <- function(params, db_path = here::here("data", "london_air.duckdb")) {
  con <- DBI::dbConnect(duckdb::duckdb(dbdir = db_path, read_only = TRUE, shared_home = FALSE))
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  q <- function(sql) DBI::dbGetQuery(con, sql)

  list(
    life_table = q("SELECT sex, age, mx, qx, ex FROM life_table ORDER BY sex, age"),
    utility    = q("SELECT version, sex, age, utility FROM utility_norms ORDER BY version, sex, age"),
    population = q(sprintf(
      "SELECT area_code, sex, age, population FROM population WHERE year = %d",
      as.integer(param_num(params, "population_year"))
    )),
    areas = q("SELECT area_code, area_name, is_city_of_london FROM areas WHERE is_london ORDER BY area_code"),
    smr   = q(sprintf(
      "SELECT area_code, value AS smr FROM indicators WHERE indicator_id = %d AND area_code LIKE 'E09%%'",
      as.integer(param_num(params, "mortality_smr_indicator"))
    ))
  )
}

# Split the "aged 90 and over" group into single years 90 to age_max in
# proportion to the England life table stationary population Lx.
split_90_plus <- function(population, life_table, age_max) {
  weights <- life_table |>
    group_by(sex) |>
    arrange(age, .by_group = TRUE) |>
    mutate(
      l      = cumprod(c(1, head(1 - qx, -1))),
      l_next = l * (1 - qx),
      L      = (l + l_next) / 2
    ) |>
    filter(age >= 90, age <= age_max) |>
    mutate(weight = L / sum(L)) |>
    ungroup() |>
    select(sex, age, weight)

  aged_90_plus <- population |>
    filter(age == 90) |>
    select(-age) |>
    inner_join(weights, by = "sex", relationship = "many-to-many") |>
    mutate(population = population * weight) |>
    select(area_code, sex, age, population)

  bind_rows(filter(population, age < 90), aged_90_plus) |>
    arrange(area_code, sex, age)
}

# Lag and effect -----------------------------------------------------------------

# Cumulative share of the full effect in force in calendar year t (t = 1 is
# the first year of the cut): 30% in year 1, +12.5% a year in years 2 to 5,
# +1.333% a year in years 6 to 20, 100% from year 20.
lag_share <- function(t, params, lag = TRUE) {
  if (!lag) return(rep(1, length(t)))
  y1   <- param_num(params, "lag_share_year1")
  y2_5 <- param_num(params, "lag_share_years2_5")
  y6_20 <- param_num(params, "lag_share_years6_20")
  share <- ifelse(
    t <= 1, y1,
    ifelse(t <= 5, y1 + y2_5 * (t - 1) / 4,
           ifelse(t <= 20, y1 + y2_5 + y6_20 * (t - 5) / 15, 1))
  )
  pmin(share, 1)
}

# Multiplier on the all-cause hazard at the full effect: about 0.9923 for
# HR 1.08 and a 1 ug/m3 cut.
hazard_multiplier <- function(hr, delta) hr^(-delta / 10)

# Cohorts ------------------------------------------------------------------------

# Per-person gains for cohorts of one sex. Cohort i enters the model at age
# entry_age[i] in calendar year entry_year[i] and is followed to age_max.
# mx_by_age and u_by_age are vectors named by age. Returns one row per cohort,
# or with by_year = TRUE a list that also holds the year-by-year gains.
cohort_gains <- function(entry_age, entry_year, mx_by_age, u_by_age, settings, params,
                         mx_scale = 1, by_year = FALSE) {
  n <- length(entry_age)
  entry_year <- rep_len(entry_year, n)
  n_years <- settings$age_max - min(entry_age) + 1
  j <- seq_len(n_years)

  age      <- outer(entry_age, j - 1, "+")
  in_range <- age <= settings$age_max
  age_used <- pmin(age, settings$age_max)
  year     <- outer(entry_year, j - 1, "+")

  mx_base <- matrix(mx_by_age[as.character(age_used)], n, n_years) * mx_scale
  share   <- matrix(lag_share(as.vector(year), params, settings$lag), n, n_years)
  mx_cut  <- mx_base * (1 - share * (1 - hazard_multiplier(settings$hr, settings$delta)))

  # Cumulative sum along each row as a matrix product with an upper triangle of ones
  upper <- upper.tri(diag(n_years), diag = TRUE) * 1
  life_years <- function(mx) {
    survival <- exp(-(mx %*% upper))
    survival_start <- cbind(1, survival[, -n_years, drop = FALSE])
    (survival_start + survival) / 2 * in_range
  }

  ly_gain  <- life_years(mx_cut) - life_years(mx_base)
  utility  <- matrix(u_by_age[as.character(age_used)], n, n_years)
  discount <- (1 + settings$r_health)^(-year)

  out <- tibble(
    entry_age   = entry_age,
    entry_year  = entry_year,
    ly          = rowSums(ly_gain),
    ly_disc     = rowSums(ly_gain * discount),
    qaly        = rowSums(ly_gain * utility),
    qaly_disc   = rowSums(ly_gain * utility * discount)
  )
  if (!by_year) return(out)
  list(gains = out, ly_by_year = ly_gain, qaly_by_year = ly_gain * utility, year = year)
}

# Life expectancy at a given age from the model's survival calculation
# (mid-year approximation, follow-up to age_max). Used to check the life table.
life_expectancy <- function(age_from, mx_by_age, age_max) {
  ages <- age_from:age_max
  survival <- exp(-cumsum(mx_by_age[as.character(ages)]))
  sum((c(1, head(survival, -1)) + survival) / 2)
}

# Per-person gains for every cohort the settings call for, for one sex:
# the closed cohort (ages age_min to age_max in year 1) and, for the open
# cohort, people who turn age_min in years 2 to open_entry_years.
person_gains <- function(sex, inputs, settings, params, mx_scale = 1) {
  lt <- filter(inputs$life_table, .data$sex == !!sex)
  mx_by_age <- set_names(lt$mx, lt$age)
  ut <- filter(inputs$utility, .data$sex == !!sex, .data$version == settings$utility_version)
  if (nrow(ut) == 0) stop("No utility norms for version ", settings$utility_version)
  u_by_age <- set_names(ut$utility, ut$age)

  closed <- cohort_gains(
    entry_age = settings$age_min:settings$age_max, entry_year = 1,
    mx_by_age, u_by_age, settings, params, mx_scale
  ) |>
    mutate(baseline_age = entry_age)

  if (settings$cohort != "open") return(mutate(closed, sex = sex))

  entry_years <- 2:settings$open_entry_years
  entrants <- cohort_gains(
    entry_age = rep(settings$age_min, length(entry_years)), entry_year = entry_years,
    mx_by_age, u_by_age, settings, params, mx_scale
  ) |>
    # People who turn age_min in year e were age_min - (e - 1) at baseline
    mutate(baseline_age = settings$age_min - (entry_year - 1))

  bind_rows(closed, entrants) |> mutate(sex = sex)
}

# Borough results ------------------------------------------------------------------

# QALYs and life-years gained by borough for one set of settings.
borough_gains <- function(inputs, settings, params) {
  population <- split_90_plus(inputs$population, inputs$life_table, settings$age_max)

  gains_for <- function(mx_scale = 1) {
    map(c("Female", "Male"), \(s) person_gains(s, inputs, settings, params, mx_scale)) |>
      list_rbind()
  }

  if (settings$mortality == "england") {
    per_person <- gains_for(1)
    totals <- population |>
      inner_join(per_person, by = c("sex", "age" = "baseline_age")) |>
      group_by(area_code)
  } else if (settings$mortality == "smr") {
    totals <- inputs$smr |>
      mutate(per_person = map(smr, \(x) gains_for(x / 100))) |>
      select(area_code, per_person) |>
      unnest(per_person) |>
      inner_join(population, by = c("area_code", "sex", "baseline_age" = "age")) |>
      group_by(area_code)
  } else {
    stop("Unknown mortality setting: ", settings$mortality)
  }

  totals |>
    summarise(
      ly_gained        = sum(population * ly),
      ly_gained_disc   = sum(population * ly_disc),
      qaly_gained      = sum(population * qaly),
      qaly_gained_disc = sum(population * qaly_disc),
      .groups = "drop"
    ) |>
    right_join(inputs$areas, by = "area_code") |>
    relocate(area_name, is_city_of_london, .after = area_code)
}

# Break-even spend -----------------------------------------------------------------

# Present value of an equal spend of 1 a year in years 1 to h
annuity_factor <- function(h, r) sum((1 + r)^(-seq_len(h)))

# Highest present value of spending that stays cost-effective
breakeven_pv <- function(health_gain_disc, threshold) health_gain_disc * threshold

# The same present value spread as an equal annual spend over h years
breakeven_annual <- function(health_gain_disc, threshold, h, r_cost) {
  breakeven_pv(health_gain_disc, threshold) / annuity_factor(h, r_cost)
}

# The discounted health gain the settings ask for: QALYs or life-years
discounted_gain <- function(results, settings) {
  if (settings$outcome == "qaly") results$qaly_gained_disc else results$ly_gained_disc
}
