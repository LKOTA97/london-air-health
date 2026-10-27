# 07_write_readme.R
# Fills README_template.md with numbers from the SQL results and model
# outputs and writes README.md, so no number in the README is typed by hand.

source(here::here("R/00_setup.R"))

con <- DBI::dbConnect(duckdb::duckdb(dbdir = paths$db, read_only = TRUE, shared_home = FALSE))
run_sql <- function(file) DBI::dbGetQuery(con, read_file(file.path(paths$sql, file)))
latest <- run_sql("01_borough_latest.sql")
trends <- run_sql("02_trends.sql")
DBI::dbDisconnect(con, shutdown = TRUE)

out <- function(file) read_csv(file.path(paths$outputs, file), show_col_types = FALSE)
london      <- out("results_london.csv")
boroughs    <- out("results_borough.csv")
breakeven   <- out("breakeven.csv")
temporary   <- out("breakeven_temporary_cut.csv")
oneway      <- out("oneway.csv")
psa         <- out("psa_summary.csv")
checks      <- out("model_checks.csv")
params      <- read_csv(file.path(paths$model, "parameters.csv"), col_types = cols(.default = "c"))
param <- function(name) as.numeric(params$value[params$name == name])

num   <- function(x, digits = 1) formatC(x, format = "f", digits = digits, big.mark = ",")
money <- function(x, digits = 2) formatC(x, format = "f", digits = digits, big.mark = ",")

threshold <- param("threshold_nice_guidelines")
horizon   <- param("horizon_years")
h_low     <- as.numeric(params$low[params$name == "horizon_years"])
h_high    <- as.numeric(params$high[params$name == "horizon_years"])

pick <- function(group, yr, col) trends[[col]][trends$area_group == group & trends$year == yr]
year_first <- min(trends$year)
year_last  <- max(trends$year)

ranked <- filter(latest, !is_city_of_london)
borough_values <- boroughs |> filter(!is_city_of_london)
psa_london <- filter(psa, area_code == "LONDON")
london_be  <- filter(breakeven, area_code == "LONDON", threshold_name == "nice_guidelines")
london_tmp <- filter(temporary, area_code == "LONDON", threshold_name == "nice_guidelines")

values <- list(
  year_first          = year_first,
  year_last           = year_last,
  london_pm25_first   = num(pick("London", year_first, "pm25")),
  london_pm25_last    = num(pick("London", year_last, "pm25")),
  england_pm25_last   = num(pick("England", year_last, "pm25")),
  london_af_last      = num(pick("London", year_last, "attributable_pct")),
  england_af_last     = num(pick("England", year_last, "attributable_pct")),
  imd_r               = num(cor(ranked$imd_score, ranked$pm25), 2),
  qaly_disc           = num(london$qaly_gained_disc, 0),
  ly_undisc           = num(london$ly_gained, 0),
  days_per_person     = num(london$days_per_person_30plus, 0),
  threshold           = num(threshold, 0),
  annual_m            = num(london$annual_breakeven / 1e6),
  horizon             = horizon,
  per_resident        = money(london$annual_per_resident),
  per_resident_low    = money(psa_london$per_resident_low),
  per_resident_high   = money(psa_london$per_resident_high),
  borough_min_value   = money(min(borough_values$annual_per_resident)),
  borough_min_name    = borough_values$area_name[which.min(borough_values$annual_per_resident)],
  borough_max_value   = money(max(borough_values$annual_per_resident)),
  borough_max_name    = borough_values$area_name[which.max(borough_values$annual_per_resident)],
  horizon_low         = h_low,
  horizon_high        = h_high,
  h_low_m             = num(london_be$annual[london_be$horizon == h_low] / 1e6),
  h_high_m            = num(london_be$annual[london_be$horizon == h_high] / 1e6),
  t_low_m             = num(london_tmp$annual[london_tmp$horizon == h_low] / 1e6),
  t_high_m            = num(london_tmp$annual[london_tmp$horizon == h_high] / 1e6),
  gb_m                = num(oneway$annual_breakeven[grepl("Green Book", oneway$scenario)] / 1e6),
  hr_low_m            = num(oneway$annual_breakeven[grepl("^HR 1.06", oneway$scenario)] / 1e6),
  hr_high_m           = num(oneway$annual_breakeven[grepl("^HR 1.09", oneway$scenario)] / 1e6),
  hr                  = param("hr_per_10ugm3"),
  le_diff             = num(max(abs(checks$difference), na.rm = TRUE), 2),
  status              = paste(
    "- [x] Data: Fingertips, ONS population and life tables, EQ-5D norms, boundaries, with a download manifest",
    "- [x] DuckDB database and data tests, including the check that Fingertips uses HR 1.08",
    "- [x] SQL: latest values by borough, trends with a population-weighted London mean, deprivation thirds",
    "- [x] Life-table model, model tests and an independent re-implementation check",
    "- [x] `model/parameters.csv` with a source for every parameter; decision log",
    "- [x] One-way sensitivity analysis and probabilistic analysis",
    "- [x] Dashboard: all six pages, checked at desktop and phone widths",
    "- [x] Notes: walkthrough, decision log, verified sources, interview preparation, SQL practice",
    "- [ ] Published on GitHub Pages (waiting for Lassi's go-ahead)",
    sep = "\n"
  )
)

template <- read_file(here::here("README_template.md"))
readme <- template
for (key in names(values)) {
  readme <- str_replace_all(readme, fixed(paste0("{{", key, "}}")), as.character(values[[key]]))
}
leftover <- str_extract_all(readme, "\\{\\{[a-z_]+\\}\\}")[[1]]
if (length(leftover) > 0) stop("Unfilled placeholders in README_template.md: ", paste(unique(leftover), collapse = ", "))

write_file(readme, here::here("README.md"))
message("README.md written (", length(values), " values filled)")
