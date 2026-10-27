# 02_get_ons.R
# Downloads ONS data: mid-year population estimates by single year of age and
# sex for London boroughs (via Nomis), and the national life tables for England.

source(here::here("R/00_setup.R"))

# Population: Nomis dataset NM_2002_1 -----------------------------------------
# "Population estimates - local authority based by single year of age".
# Geography 2013265927TYPE423 means every local authority (county / unitary as
# of April 2023) inside the London region, which gives the 33 E09 areas.
# Ages are codes 101 (age 0) to 190 (age 89) plus 191 (aged 90+).
# Nomis returns at most 25,000 rows per request, so we ask for one year at a time.

nomis_url <- function(year) {
  paste0(
    "https://www.nomisweb.co.uk/api/v01/dataset/NM_2002_1.data.csv",
    "?geography=2013265927TYPE423",
    "&date=", year,
    "&gender=1,2",
    "&c_age=101...191",
    "&measures=20100",
    "&select=date_name,geography_code,geography_name,gender_name,c_age_name,obs_value"
  )
}

population_years <- 2018:2025

population <- map(population_years, \(year) {
  tmp <- tempfile(fileext = ".csv")
  download_to(nomis_url(year), tmp)
  read_csv(tmp, col_types = cols(.default = col_character()), na = character())
}) |>
  list_rbind()

pop_file <- "ons_population_london_2018_2025.csv"
write_csv(population, file.path(paths$raw, pop_file), na = "")
record_download(pop_file, nomis_url(paste(range(population_years), collapse = "-")), nrow(population))

# London region total for a cross-check of the borough sum
london_total_url <- paste0(
  "https://www.nomisweb.co.uk/api/v01/dataset/NM_2002_1.data.csv",
  "?geography=2013265927&date=", paste(range(population_years), collapse = "-"),
  "&gender=0&c_age=200&measures=20100&select=date_name,geography_code,geography_name,obs_value"
)
london_total_file <- "ons_population_london_region_total.csv"
download_to(london_total_url, file.path(paths$raw, london_total_file))
london_total <- read_csv(file.path(paths$raw, london_total_file), show_col_types = FALSE)
record_download(london_total_file, london_total_url, nrow(london_total))

check <- population |>
  mutate(obs_value = as.integer(OBS_VALUE), year = as.integer(DATE_NAME)) |>
  summarise(
    areas = n_distinct(GEOGRAPHY_CODE),
    ages = n_distinct(C_AGE_NAME),
    borough_sum = sum(obs_value),
    .by = year
  ) |>
  left_join(
    transmute(london_total, year = DATE_NAME, region_total = OBS_VALUE),
    by = "year"
  ) |>
  mutate(difference = borough_sum - region_total)

print(check)
stopifnot(all(check$areas == 33), all(check$ages == 91), all(check$difference == 0))

# National life tables, England ------------------------------------------------
# ONS "National life tables: England" reference tables, released 10 December
# 2025, covering 1980-1982 to 2022-2024. One sheet per three-year period, each
# with males (columns A to F) and females (columns H to M): age, mx, qx, lx, dx, ex.
# The file name changes with each edition, so we pin this one and commit it.

life_table_url <- paste0(
  "https://www.ons.gov.uk/file?uri=/peoplepopulationandcommunity/birthsdeathsandmarriages/",
  "lifeexpectancies/datasets/nationallifetablesenglandreferencetables/current/nlte198020223.xlsx"
)
life_table_file <- "ons_national_life_tables_england_1980_2024.xlsx"
download_to(life_table_url, file.path(paths$raw, life_table_file))

life_table_period <- "2022-2024"
sheets <- readxl::excel_sheets(file.path(paths$raw, life_table_file))
stopifnot(life_table_period %in% sheets)
latest <- readxl::read_excel(file.path(paths$raw, life_table_file), sheet = life_table_period, skip = 5)
record_download(life_table_file, life_table_url, nrow(latest))
message("Life table sheets: ", length(sheets), "; rows in ", life_table_period, " sheet: ", nrow(latest))
