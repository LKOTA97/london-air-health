# 01_get_fingertips.R
# Downloads indicator data and metadata from the OHID Fingertips API.
#
# For each indicator we request upper-tier local authorities (area type 502)
# and keep the 33 London areas (codes starting E09) plus the England rows.
# Every column is read as text so the saved file holds the values exactly as
# the API sent them. Each file is recorded in data/raw/MANIFEST.csv.

source(here::here("R/00_setup.R"))

get_fingertips_indicator <- function(name, id) {
  url <- sprintf(
    "%s/all_data/csv/by_indicator_id?indicator_ids=%d&child_area_type_id=%d",
    fingertips_api, id, area_type_utla
  )
  tmp <- tempfile(fileext = ".csv")
  download_to(url, tmp)

  d <- read_csv(tmp, col_types = cols(.default = col_character()), na = character())
  d <- filter(d, startsWith(`Area Code`, london_code_prefix) | `Area Type` == "England")

  file <- sprintf("fingertips_%d_%s.csv", id, name)
  write_csv(d, file.path(paths$raw, file), na = "")
  record_download(file, url, nrow(d))

  tibble(
    file           = file,
    indicator_id   = id,
    indicator_name = first(d$`Indicator Name`),
    rows           = nrow(d),
    london_areas   = n_distinct(d$`Area Code`[startsWith(d$`Area Code`, london_code_prefix)]),
    periods        = paste(range(d$`Time period Sortable`) |> substr(1, 4), collapse = " to ")
  )
}

summary <- imap(fingertips_indicators, \(id, name) get_fingertips_indicator(name, id)) |>
  list_rbind()

# London region values for the two air pollution indicators (area type 6,
# Government Office Regions). Used only to check our population-weighted
# London mean against the official London figure.
london_region_code <- "E12000007"
region_url <- sprintf(
  "%s/all_data/csv/by_indicator_id?indicator_ids=%s&child_area_type_id=6",
  fingertips_api,
  paste(fingertips_indicators[c("pm25_concentration", "pm25_mortality_share")], collapse = ",")
)
tmp <- tempfile(fileext = ".csv")
download_to(region_url, tmp)
region <- read_csv(tmp, col_types = cols(.default = col_character()), na = character()) |>
  filter(`Area Code` == london_region_code)
region_file <- "fingertips_london_region_air_pollution.csv"
write_csv(region, file.path(paths$raw, region_file), na = "")
record_download(region_file, region_url, nrow(region))
message("London region rows: ", nrow(region))

# Indicator definitions, methods and caveats, kept as the source for how each
# indicator is calculated (for example the COMEAP coefficient behind 93861).
meta_url <- sprintf(
  "%s/indicator_metadata/csv/by_indicator_id?indicator_ids=%s",
  fingertips_api, paste(fingertips_indicators, collapse = ",")
)
meta_file <- "fingertips_metadata.csv"
download_to(meta_url, file.path(paths$raw, meta_file))
meta_rows <- nrow(read_csv(file.path(paths$raw, meta_file), col_types = cols(.default = "c")))
record_download(meta_file, meta_url, meta_rows)

print(summary, width = Inf)
message("Metadata rows: ", meta_rows)
