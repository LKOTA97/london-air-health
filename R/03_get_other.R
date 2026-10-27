# 03_get_other.R
# Downloads the remaining inputs:
# 1. EQ-5D-3L population norms by age and sex (NICE Decision Support Unit)
# 2. London borough boundaries (ONS Open Geography Portal)

source(here::here("R/00_setup.R"))

# 1. EQ-5D-3L by age and sex ---------------------------------------------------
# Hernández Alava M, Pudney S, Wailoo A. Estimating EQ-5D by Age and Sex for the
# UK. NICE DSU report, 12 January 2022. The report recommends the Health Survey
# for England 2014 values (section 6). The spreadsheet's "Expected EQ-5D-3L"
# sheet gives them by single year of age (16 to 101) and sex.
# The file is an old-format .xls even though the website does not say so.
# It has no open licence, so it is downloaded but not committed (see .gitignore).

eq5d_url  <- "https://sheffield.ac.uk/media/34060/download?attachment"
eq5d_file <- "dsu_eq5d_3l_by_age_sex_hse2014.xls"
download_to(eq5d_url, file.path(paths$raw, eq5d_file))

eq5d_sheet <- "Expected EQ-5D-3L"
stopifnot(eq5d_sheet %in% readxl::excel_sheets(file.path(paths$raw, eq5d_file)))
eq5d <- readxl::read_xls(file.path(paths$raw, eq5d_file), sheet = eq5d_sheet, skip = 1)
record_download(eq5d_file, eq5d_url, nrow(eq5d))
message("EQ-5D rows (single years of age): ", nrow(eq5d))

# 2. London borough boundaries -------------------------------------------------
# Local Authority Districts (May 2026) Boundaries UK BUC: ultra generalised
# (500 m), clipped to the coastline. We request only codes starting E09 and ask
# the server for WGS84 coordinates (EPSG:4326), which leaflet needs.

boundaries_url <- paste0(
  "https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/",
  "Local_Authority_Districts_May_2026_Boundaries_UK_BUC/FeatureServer/0/query",
  "?where=LAD26CD%20LIKE%20%27E09%25%27",
  "&outFields=LAD26CD,LAD26NM",
  "&outSR=4326",
  "&f=geojson"
)
boundaries_file <- "ons_lad_may2026_buc_london.geojson"
download_to(boundaries_url, file.path(paths$raw, boundaries_file))

boundaries <- sf::st_read(file.path(paths$raw, boundaries_file), quiet = TRUE)
stopifnot(nrow(boundaries) == 33, all(startsWith(boundaries$LAD26CD, london_code_prefix)))
record_download(boundaries_file, boundaries_url, nrow(boundaries))
message("Boundary features: ", nrow(boundaries), "; file size: ",
        round(file.size(file.path(paths$raw, boundaries_file)) / 1024), " KB")
