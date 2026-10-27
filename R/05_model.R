# 05_model.R
# Deterministic base case of the life-table model: QALYs and life-years
# gained by borough from a sustained 1 ug/m3 cut in PM2.5, and the
# break-even spend at each threshold and horizon. Writes CSVs to outputs/.

source(here::here("R/00_setup.R"))
source(here::here("R/model_functions.R"))

params   <- read_parameters()
settings <- base_settings(params)
inputs   <- load_model_inputs(params)
dir.create(paths$outputs, showWarnings = FALSE)

# Thresholds and horizons, all from model/parameters.csv. The NICE thresholds
# use NICE discounting (3.5% for health). The societal value is a Green Book
# cost-benefit value, so it uses the Green Book health discount rate (1.5%).
thresholds <- tibble(
  threshold_name = c("nice_guidelines", "nice_previous_upper", "ta_low", "ta_high", "societal"),
  threshold_label = c(
    "NICE guidelines", "NICE previous upper", "Technology appraisal lower",
    "Technology appraisal upper", "Societal value (Defra, Green Book conventions)"
  ),
  threshold = c(
    param_num(params, "threshold_nice_guidelines"),
    param_num(params, "threshold_nice_previous_upper"),
    param_num(params, "threshold_ta_low"),
    param_num(params, "threshold_ta_high"),
    param_num(params, "value_qaly_societal")
  ),
  health_discount = c(rep("nice", 4), "green_book")
)
green_book_health_rate <- param_num(params, "discount_rate_health_scenario")
horizons <- c(
  param_bound(params, "horizon_years", "low"),
  settings$horizon,
  param_bound(params, "horizon_years", "high")
)
base_threshold <- param_num(params, "threshold_nice_guidelines")

# Population (mid-2025) for per-resident figures
population_totals <- inputs$population |>
  group_by(area_code) |>
  # The 30+ total comes first: once summarise() has replaced `population` with
  # its sum, it can no longer be subset by age
  summarise(
    population_30plus = sum(population[age >= settings$age_min]),
    population        = sum(population),
    .groups = "drop"
  )

# Base case by borough -----------------------------------------------------------

boroughs <- borough_gains(inputs, settings, params) |>
  left_join(population_totals, by = "area_code")

london <- boroughs |>
  summarise(across(c(ly_gained, ly_gained_disc, qaly_gained, qaly_gained_disc, population, population_30plus), sum)) |>
  mutate(area_code = "LONDON", area_name = "London", is_city_of_london = FALSE, .before = 1)

add_headline <- function(d) {
  d |>
    mutate(
      qaly_disc_per_100k_30plus = qaly_gained_disc / population_30plus * 1e5,
      days_per_person_30plus    = ly_gained / population_30plus * 365.25,
      pv_breakeven              = breakeven_pv(qaly_gained_disc, base_threshold),
      annual_breakeven          = breakeven_annual(qaly_gained_disc, base_threshold, settings$horizon, settings$r_cost),
      annual_per_resident       = annual_breakeven / population
    )
}

results_borough <- add_headline(boroughs) |> arrange(desc(qaly_gained_disc))
results_london  <- add_headline(london)

write_csv(results_borough, file.path(paths$outputs, "results_borough.csv"))
write_csv(results_london,  file.path(paths$outputs, "results_london.csv"))

# Break-even spend at every threshold and horizon ----------------------------------

# QALYs discounted at the Green Book health rate, for the societal value
green_book <- borough_gains(inputs, modifyList(settings, list(r_health = green_book_health_rate)), params) |>
  select(area_code, qaly_gained_disc_green_book = qaly_gained_disc)
green_book <- bind_rows(
  green_book,
  tibble(area_code = "LONDON", qaly_gained_disc_green_book = sum(green_book$qaly_gained_disc_green_book))
)

breakeven <- bind_rows(results_borough, results_london) |>
  select(area_code, area_name, is_city_of_london, qaly_gained_disc, population) |>
  left_join(green_book, by = "area_code") |>
  cross_join(thresholds) |>
  cross_join(tibble(horizon = horizons)) |>
  mutate(
    health_gain_disc    = ifelse(health_discount == "green_book", qaly_gained_disc_green_book, qaly_gained_disc),
    pv                  = breakeven_pv(health_gain_disc, threshold),
    annuity_factor      = map_dbl(horizon, \(h) annuity_factor(h, settings$r_cost)),
    annual              = pv / annuity_factor,
    annual_per_resident = annual / population
  )
write_csv(breakeven, file.path(paths$outputs, "breakeven.csv"))

# Alternative view: the cut lasts only while it is paid for (H years), then
# the benefit fades on the same lag. The annual figure then barely depends on H.
temporary <- map(horizons, \(h) {
  r <- borough_gains(inputs, modifyList(settings, list(cut_years = h)), params)
  bind_rows(
    select(r, area_code, area_name, qaly_gained_disc),
    tibble(area_code = "LONDON", area_name = "London", qaly_gained_disc = sum(r$qaly_gained_disc))
  ) |>
    mutate(horizon = h)
}) |>
  list_rbind() |>
  cross_join(filter(thresholds, health_discount == "nice") |> select(threshold_name, threshold_label, threshold)) |>
  mutate(
    annuity_factor = map_dbl(horizon, \(h) annuity_factor(h, settings$r_cost)),
    annual = breakeven_pv(qaly_gained_disc, threshold) / annuity_factor
  )
write_csv(temporary, file.path(paths$outputs, "breakeven_temporary_cut.csv"))

# How the annual figure depends on the horizon, for 1 million of present value
annuity_table <- tibble(horizon = horizons) |>
  mutate(
    r_cost         = settings$r_cost,
    annuity_factor = map_dbl(horizon, \(h) annuity_factor(h, settings$r_cost)),
    annual_per_1m_pv = 1e6 / annuity_factor
  )
write_csv(annuity_table, file.path(paths$outputs, "annuity_factors.csv"))

# London gains year by year (closed cohort) ----------------------------------------

population_split <- split_90_plus(inputs$population, inputs$life_table, settings$age_max)
by_year <- map(c("Female", "Male"), \(s) {
  lt <- filter(inputs$life_table, sex == s)
  ut <- filter(inputs$utility, sex == s, version == settings$utility_version)
  ages <- settings$age_min:settings$age_max
  res <- cohort_gains(ages, 1, set_names(lt$mx, lt$age), set_names(ut$utility, ut$age),
                      settings, params, by_year = TRUE)
  weights <- population_split |>
    filter(sex == s) |>
    group_by(age) |>
    summarise(population = sum(population), .groups = "drop")
  w <- weights$population[match(ages, weights$age)]
  tibble(
    year      = res$year[1, ],
    ly        = colSums(res$ly_by_year * w),
    qaly      = colSums(res$qaly_by_year * w)
  )
}) |>
  list_rbind() |>
  group_by(year) |>
  summarise(across(c(ly, qaly), sum), .groups = "drop") |>
  mutate(
    lag_share = lag_share(year, params, settings$lag),
    qaly_disc = qaly * (1 + settings$r_health)^(-year)
  )
write_csv(by_year, file.path(paths$outputs, "london_gains_by_year.csv"))

# Model checks -----------------------------------------------------------------------

checks <- map(c("Female", "Male"), \(s) {
  lt <- filter(inputs$life_table, sex == s)
  tibble(
    check = paste("Life expectancy at", settings$age_min, "-", s),
    model = life_expectancy(settings$age_min, set_names(lt$mx, lt$age), settings$age_max),
    reference = lt$ex[lt$age == settings$age_min]
  )
}) |>
  list_rbind() |>
  bind_rows(tibble(
    check = "Hazard multiplier at full effect",
    model = hazard_multiplier(settings$hr, settings$delta),
    reference = NA_real_
  )) |>
  mutate(difference = model - reference)
write_csv(checks, file.path(paths$outputs, "model_checks.csv"))

# Summary ------------------------------------------------------------------------------

message("London: ", format(round(results_london$qaly_gained_disc), big.mark = ","), " discounted QALYs; ",
        "annual break-even at ", base_threshold, " per QALY over ", settings$horizon, " years: ",
        format(round(results_london$annual_breakeven), big.mark = ","),
        " (", round(results_london$annual_per_resident, 2), " per resident)")
print(checks)
