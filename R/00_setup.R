# 00_setup.R
# Packages, paths and constants shared by every script.
# Each script starts with: source(here::here("R/00_setup.R"))

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(stringr)
  library(here)
})

# ONS and Fingertips files can take more than R's default 60 seconds
options(timeout = 300)

# Paths ------------------------------------------------------------------------

paths <- list(
  raw      = here("data", "raw"),
  clean    = here("data", "clean"),
  db       = here("data", "london_air.duckdb"),
  sql      = here("sql"),
  model    = here("model"),
  outputs  = here("outputs"),
  manifest = here("data", "raw", "MANIFEST.csv")
)

# Fingertips -------------------------------------------------------------------

fingertips_api <- "https://fingertips.phe.org.uk/api"

# Upper-tier local authorities (from April 2023). London boroughs have codes
# starting E09: 32 boroughs plus the City of London.
area_type_utla      <- 502L
london_code_prefix  <- "E09"
city_of_london_code <- "E09000001"

fingertips_indicators <- c(
  pm25_concentration     = 93867L,
  pm25_mortality_share   = 93861L,
  asthma_admissions_u19  = 90810L,
  copd_admissions_35plus = 92302L,
  imd_2019_score         = 93553L
)

# Helpers ----------------------------------------------------------------------

# Add or replace one row in data/raw/MANIFEST.csv for a downloaded file.
record_download <- function(file, url, rows) {
  entry <- tibble(
    file          = file,
    url           = url,
    downloaded_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    rows          = as.integer(rows)
  )
  manifest <- if (file.exists(paths$manifest)) {
    read_csv(paths$manifest, col_types = "ccci")
  } else {
    entry[0, ]
  }
  manifest <- manifest |>
    filter(.data$file != !!file) |>
    bind_rows(entry) |>
    arrange(.data$file)
  write_csv(manifest, paths$manifest)
  invisible(manifest)
}
