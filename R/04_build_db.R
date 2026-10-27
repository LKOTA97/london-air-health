# 04_build_db.R
# Tidies the raw downloads into five tables, writes them to data/clean/ as
# CSV, and loads them into DuckDB at data/london_air.duckdb.
#
# Tables
#   indicators    one row per area, indicator and period (Fingertips)
#   areas         the 33 London areas, the London region and England
#   population    mid-year population by area, sex, single year of age, year
#   life_table    England national life table, 2022-2024, by sex and age
#   utility_norms EQ-5D by version (5L and 3L), sex and single year of age

source(here::here("R/00_setup.R"))
library(DBI)

london_region_code <- "E12000007"
england_code       <- "E92000001"

# Indicators -------------------------------------------------------------------

# The breakdown to keep for each indicator. Fingertips files also hold
# deprivation-decile rows (Category Type is filled in) and, for some
# indicators, male, female and age-band rows that we do not use.
keep_breakdown <- tribble(
  ~indicator_id, ~sex,             ~age,
  93867L,        "Not applicable", "Not applicable",
  93861L,        "Persons",        "30+ yrs",
  90810L,        "Persons",        "0-18 yrs",
  92302L,        "Persons",        "35+ yrs",
  93553L,        "Persons",        "All ages",
  94240L,        "Persons",        "All ages",
  93250L,        "Persons",        "All ages",
  93823L,        "Persons",        "All ages"
)

indicator_keys <- tibble(
  indicator_id  = unname(fingertips_indicators),
  indicator_key = names(fingertips_indicators)
)

raw_files <- c(
  list.files(paths$raw, pattern = "^fingertips_9\\d+_.*\\.csv$", full.names = TRUE),
  file.path(paths$raw, "fingertips_london_region_air_pollution.csv")
)

parse_num <- function(x) parse_double(x, na = "")

indicators <- raw_files |>
  map(\(f) read_csv(f, col_types = cols(.default = col_character()), na = character())) |>
  list_rbind() |>
  filter(`Category Type` == "") |>
  transmute(
    area_code      = `Area Code`,
    area_name      = `Area Name`,
    area_type      = case_when(
      startsWith(area_code, london_code_prefix) ~ "Local authority",
      area_code == london_region_code           ~ "Region",
      area_code == england_code                 ~ "Country"
    ),
    indicator_id   = as.integer(`Indicator ID`),
    indicator_name = `Indicator Name`,
    period         = `Time period`,
    # "Time period Sortable" is YYYY0000 for the first calendar year, so this
    # works for "2018", "2023/24" and pooled periods such as "2019 - 23".
    year_start     = as.integer(substr(`Time period Sortable`, 1, 4)),
    sex            = Sex,
    age            = Age,
    value          = parse_num(Value),
    lower_ci       = parse_num(`Lower CI 95.0 limit`),
    upper_ci       = parse_num(`Upper CI 95.0 limit`),
    count          = parse_num(Count),
    denominator    = parse_num(Denominator),
    value_note     = na_if(`Value note`, "")
  ) |>
  semi_join(keep_breakdown, by = c("indicator_id", "sex", "age")) |>
  # England appears twice in each file (once as its own parent area) with
  # identical values, so we keep one copy.
  distinct() |>
  left_join(indicator_keys, by = "indicator_id") |>
  relocate(indicator_key, .after = indicator_id) |>
  arrange(indicator_id, area_code, year_start)

# Areas ------------------------------------------------------------------------

areas <- indicators |>
  distinct(area_code, area_name, area_type) |>
  mutate(
    is_london         = startsWith(area_code, london_code_prefix),
    is_city_of_london = area_code == city_of_london_code
  ) |>
  arrange(desc(is_london), area_code)

stopifnot(!anyDuplicated(areas$area_code))

# Population -------------------------------------------------------------------

population <- read_csv(
  file.path(paths$raw, "ons_population_london_2018_2025.csv"),
  col_types = cols(.default = col_character())
) |>
  transmute(
    area_code  = GEOGRAPHY_CODE,
    sex        = GENDER_NAME,
    # "Age 0" to "Age 89", then "Aged 90+": age 90 means 90 and over
    age        = as.integer(str_extract(C_AGE_NAME, "\\d+")),
    population = as.integer(OBS_VALUE),
    year       = as.integer(DATE_NAME)
  ) |>
  arrange(year, area_code, sex, age)

# Life table -------------------------------------------------------------------
# Sheet "2022-2024": row 6 holds the headers; males in columns 1 to 6,
# females in columns 8 to 13, each age, mx, qx, lx, dx, ex.

life_table_period <- "2022-2024"
lt_path <- file.path(paths$raw, "ons_national_life_tables_england_1980_2024.xlsx")
lt_raw  <- readxl::read_excel(lt_path, sheet = life_table_period, col_names = FALSE, skip = 5,
                              .name_repair = "minimal")

lt_header <- unlist(lt_raw[1, ], use.names = FALSE)
stopifnot(
  identical(lt_header[1:6],  c("age", "mx", "qx", "lx", "dx", "ex")),
  identical(lt_header[8:13], c("age", "mx", "qx", "lx", "dx", "ex"))
)

tidy_life_table <- function(cols, sex) {
  lt_raw[-1, cols] |>
    set_names(c("age", "mx", "qx", "lx", "dx", "ex")) |>
    mutate(across(everything(), as.numeric)) |>
    transmute(sex = sex, age = as.integer(age), mx, qx, ex, period = life_table_period)
}

life_table <- bind_rows(
  tidy_life_table(1:6,  "Male"),
  tidy_life_table(8:13, "Female")
)

# Utility norms ----------------------------------------------------------------

# EQ-5D-5L (EEPRU 2026, HSE 2017-18): columns are Age, males, females.
# EQ-5D-3L (NICE DSU 2022, HSE 2014): columns are age, Females, Males.
utility_5l <- readxl::read_excel(
  file.path(paths$raw, "eepru_eq5d_5l_by_age_sex_hse2017_2018.xlsx"),
  sheet = "Predictions"
) |>
  set_names(c("age", "Male", "Female")) |>
  mutate(version = "EQ-5D-5L")

utility_3l <- readxl::read_xls(
  file.path(paths$raw, "dsu_eq5d_3l_by_age_sex_hse2014.xls"),
  sheet = "Expected EQ-5D-3L", skip = 1
) |>
  set_names(c("age", "Female", "Male")) |>
  mutate(version = "EQ-5D-3L")

utility_norms <- bind_rows(utility_5l, utility_3l) |>
  mutate(across(c(age, Female, Male), as.numeric)) |>
  pivot_longer(c(Female, Male), names_to = "sex", values_to = "utility") |>
  transmute(version, sex, age = as.integer(age), utility) |>
  arrange(version, sex, age)

# Boundaries -------------------------------------------------------------------

boundaries <- sf::st_read(file.path(paths$raw, "ons_lad_may2026_buc_london.geojson"), quiet = TRUE) |>
  select(area_code = LAD26CD, area_name = LAD26NM)

# Write clean files ------------------------------------------------------------

clean_tables <- list(
  indicators    = indicators,
  areas         = areas,
  population    = population,
  life_table    = life_table,
  utility_norms = utility_norms
)

iwalk(clean_tables, \(d, name) write_csv(d, file.path(paths$clean, paste0(name, ".csv")), na = ""))

boundaries_path <- file.path(paths$clean, "london_boundaries.geojson")
if (file.exists(boundaries_path)) invisible(file.remove(boundaries_path))
sf::st_write(boundaries, boundaries_path, quiet = TRUE)

# Load DuckDB ------------------------------------------------------------------
# Rebuilt from scratch each run so it always matches data/clean/.
# Written in the v1.2.0 storage format so older DuckDB tools (for example the
# DuckDB command-line tool, which can lag behind the R package) can open it.

if (file.exists(paths$db)) invisible(file.remove(paths$db))
con <- dbConnect(duckdb::duckdb(
  dbdir       = paths$db,
  shared_home = FALSE,
  config      = list(storage_compatibility_version = "v1.2.0")
))
iwalk(clean_tables, \(d, name) dbWriteTable(con, name, d))

row_counts <- map(names(clean_tables), \(t) {
  dbGetQuery(con, sprintf("SELECT '%s' AS table_name, COUNT(*) AS n_rows FROM %s", t, t))
}) |>
  list_rbind()
print(row_counts)

dbDisconnect(con, shutdown = TRUE)
