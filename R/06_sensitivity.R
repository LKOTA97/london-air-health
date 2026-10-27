# 06_sensitivity.R
# One-way sensitivity analysis (tornado) and probabilistic sensitivity
# analysis (PSA) for London's break-even annual spend.
# Base: closed cohort, HR 1.08, US EPA lag, EQ-5D-5L, England mortality,
# 3.5% discounting, 20,000 per QALY (NICE guidelines), 20-year horizon.

source(here::here("R/00_setup.R"))
source(here::here("R/model_functions.R"))

params   <- read_parameters()
settings <- base_settings(params)
inputs   <- load_model_inputs(params)
dir.create(paths$outputs, showWarnings = FALSE)

base_threshold   <- param_num(params, "threshold_nice_guidelines")
upper_threshold  <- param_num(params, "threshold_nice_previous_upper")
london_residents <- sum(inputs$population$population)

# London break-even annual spend for one set of settings
london_result <- function(s) {
  r <- borough_gains(inputs, s, params)
  gain <- sum(discounted_gain(r, s))
  tibble(
    health_gain_disc = gain,
    annual_breakeven = breakeven_annual(gain, base_threshold, s$horizon, s$r_cost)
  )
}

# One-way analysis -------------------------------------------------------------------

scenarios <- tribble(
  ~input,                          ~scenario,                                      ~changes,
  "Hazard ratio",                  "HR 1.06 (lower 95% limit)",                    list(hr = param_bound(params, "hr_per_10ugm3", "low")),
  "Hazard ratio",                  "HR 1.09 (upper 95% limit)",                    list(hr = param_bound(params, "hr_per_10ugm3", "high")),
  "Cessation lag",                 "No lag (full effect from year 1)",             list(lag = FALSE),
  "Discount rates",                "1.5% for costs and health (NICE PMG20)",       list(r_health = param_num(params, "discount_rate_scenario_nice"),
                                                                                         r_cost   = param_num(params, "discount_rate_scenario_nice")),
  "Discount rates",                "1.5% for health, 3.5% for costs (Green Book)", list(r_health = param_num(params, "discount_rate_health_scenario")),
  "Discount rates",                "3.0% for costs and health (Discount Rate Review)", list(r_health = param_num(params, "discount_rate_scenario_review"),
                                                                                         r_cost   = param_num(params, "discount_rate_scenario_review")),
  "Cohort",                        "Open cohort (adds residents turning 30 in years 2 to 20)", list(cohort = "open"),
  "Health outcome",                "Life-years, not quality-weighted",             list(outcome = "ly"),
  "Baseline mortality",            "Borough SMR instead of England rates",         list(mortality = "smr"),
  "Horizon for the annual spend",  "10 years",                                     list(horizon = param_bound(params, "horizon_years", "low")),
  "Horizon for the annual spend",  "30 years",                                     list(horizon = param_bound(params, "horizon_years", "high"))
)

base <- london_result(settings)

oneway <- scenarios |>
  mutate(result = map(changes, \(ch) london_result(modifyList(settings, ch)))) |>
  select(-changes) |>
  unnest(result) |>
  mutate(
    base_annual         = base$annual_breakeven,
    ratio_to_base       = annual_breakeven / base_annual,
    annual_per_resident = annual_breakeven / london_residents
  )
write_csv(oneway, file.path(paths$outputs, "oneway.csv"))

# Tornado: for each input, the lowest and highest result (including the base
# value for inputs with a single alternative), and the factor-of-two check.
tornado <- oneway |>
  group_by(input) |>
  summarise(
    low_value   = min(c(annual_breakeven, first(base_annual))),
    high_value  = max(c(annual_breakeven, first(base_annual))),
    low_label   = c(scenario, "Base case")[which.min(c(annual_breakeven, first(base_annual)))],
    high_label  = c(scenario, "Base case")[which.max(c(annual_breakeven, first(base_annual)))],
    .groups = "drop"
  ) |>
  mutate(
    base_value = base$annual_breakeven,
    swing      = high_value - low_value,
    max_ratio  = high_value / low_value,
    more_than_double = max_ratio > 2
  ) |>
  arrange(desc(swing))
write_csv(tornado, file.path(paths$outputs, "tornado.csv"))

# Inputs that move the answer by more than a factor of two: results across
# that input for every borough, so no single number hides the spread.
flagged <- tornado$input[tornado$more_than_double]
across_flagged <- scenarios |>
  filter(input %in% flagged) |>
  add_row(input = flagged, scenario = "Base case", changes = rep(list(list()), length(flagged))) |>
  mutate(result = map(changes, \(ch) {
    s <- modifyList(settings, ch)
    r <- borough_gains(inputs, s, params)
    tibble(
      area_code = r$area_code,
      area_name = r$area_name,
      is_city_of_london = r$is_city_of_london,
      health_gain_disc  = discounted_gain(r, s),
      annual_breakeven  = breakeven_annual(health_gain_disc, base_threshold, s$horizon, s$r_cost)
    )
  })) |>
  select(-changes) |>
  unnest(result)
write_csv(across_flagged, file.path(paths$outputs, "factor_of_two.csv"))

# Comparisons that are not uncertainty around the base case, kept out of the
# tornado: the pre-2026 NICE utility method, and the view in which the cut
# lasts only while it is paid for.
comparisons <- tribble(
  ~comparison,                                                     ~changes,
  "EQ-5D-3L norms (NICE DSU 2022, pre-2026 NICE method)",          list(utility_version = "EQ-5D-3L"),
  "Cut lasts only while it is paid for (20 years), then fades",    list(cut_years = settings$horizon)
) |>
  mutate(result = map(changes, \(ch) london_result(modifyList(settings, ch)))) |>
  select(-changes) |>
  unnest(result) |>
  mutate(base_annual = base$annual_breakeven, ratio_to_base = annual_breakeven / base_annual)
write_csv(comparisons, file.path(paths$outputs, "comparisons.csv"))

# Probabilistic sensitivity analysis ----------------------------------------------------
# Only the hazard ratio is drawn: log(HR) ~ Normal(log(1.08), se). The utility
# norms are held fixed because the sources give no standard errors for the
# predicted means (decision D12).

n_draws <- param_num(params, "psa_draws")
set.seed(param_num(params, "psa_seed"))
hr_draws <- exp(rnorm(n_draws, log(settings$hr), param_num(params, "hr_log_se")))

hr_check <- tibble(
  quantity  = c("2.5th percentile", "median", "97.5th percentile"),
  drawn     = unname(quantile(hr_draws, c(0.025, 0.5, 0.975))),
  published = c(param_bound(params, "hr_per_10ugm3", "low"), settings$hr,
                param_bound(params, "hr_per_10ugm3", "high"))
)
write_csv(hr_check, file.path(paths$outputs, "psa_hr_check.csv"))

# Population matrix: rows are areas, columns are sex x single year of age.
# Each draw then needs only the per-person gains and one matrix product.
population <- split_90_plus(inputs$population, inputs$life_table, settings$age_max) |>
  filter(age >= settings$age_min) |>
  mutate(key = paste(sex, age)) |>
  select(area_code, key, population) |>
  pivot_wider(names_from = key, values_from = population, values_fill = 0) |>
  arrange(area_code)
pop_matrix <- as.matrix(select(population, -area_code))
area_codes <- population$area_code

per_person_qaly_disc <- function(hr) {
  s <- modifyList(settings, list(hr = hr))
  g <- map(c("Female", "Male"), \(sx) person_gains(sx, inputs, s, params)) |> list_rbind()
  set_names(g$qaly_disc, paste(g$sex, g$baseline_age))[colnames(pop_matrix)]
}

draws <- map(hr_draws, per_person_qaly_disc)
qaly_draws <- pop_matrix %*% do.call(cbind, draws)    # areas x draws
annual_draws <- qaly_draws * base_threshold / annuity_factor(settings$horizon, settings$r_cost)

residents <- inputs$population |>
  group_by(area_code) |>
  summarise(population = sum(population), .groups = "drop")
residents <- residents$population[match(area_codes, residents$area_code)]

summarise_draws <- function(x, residents) {
  tibble(
    annual_median = median(x),
    annual_low    = unname(quantile(x, 0.025)),
    annual_high   = unname(quantile(x, 0.975)),
    per_resident_median = median(x) / residents,
    per_resident_low    = unname(quantile(x, 0.025)) / residents,
    per_resident_high   = unname(quantile(x, 0.975)) / residents
  )
}

psa_borough <- map(seq_along(area_codes), \(i) summarise_draws(annual_draws[i, ], residents[i])) |>
  list_rbind() |>
  mutate(area_code = area_codes, .before = 1) |>
  left_join(inputs$areas, by = "area_code") |>
  relocate(area_name, is_city_of_london, .after = area_code)

london_draws <- colSums(annual_draws)
psa_london <- summarise_draws(london_draws, london_residents) |>
  mutate(area_code = "LONDON", area_name = "London", is_city_of_london = FALSE, .before = 1)

write_csv(bind_rows(psa_borough, psa_london), file.path(paths$outputs, "psa_summary.csv"))
write_csv(
  tibble(draw = seq_len(n_draws), hr = hr_draws, qaly_gained_disc = colSums(qaly_draws),
         annual_breakeven = london_draws),
  file.path(paths$outputs, "psa_draws_london.csv")
)

# Acceptability curve: for an annual scheme cost per London resident, the
# share of draws in which the scheme is cost-effective (the break-even spend
# is at least the cost), at 20,000 and 30,000 per QALY.
per_resident_20k <- london_draws / london_residents
cost_grid <- seq(0, ceiling(max(per_resident_20k) * upper_threshold / base_threshold * 1.1), by = 0.1)
acceptability <- map(c(base_threshold, upper_threshold), \(thr) {
  breakeven <- per_resident_20k * thr / base_threshold
  tibble(
    threshold = thr,
    annual_cost_per_resident = cost_grid,
    annual_cost_london = cost_grid * london_residents,
    prob_cost_effective = map_dbl(cost_grid, \(y) mean(breakeven >= y))
  )
}) |>
  list_rbind()
write_csv(acceptability, file.path(paths$outputs, "acceptability.csv"))

# Summary ---------------------------------------------------------------------------------
message("Base London annual break-even: ", format(round(base$annual_breakeven), big.mark = ","))
print(select(tornado, input, low_label, low_value, high_label, high_value, max_ratio), width = 200)
print(hr_check)
print(psa_london, width = 200)
