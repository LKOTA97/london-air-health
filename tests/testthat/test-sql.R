# Checks on the SQL queries in sql/. Each test is skipped until its file exists.
# The expected values are calculated here in R, independently of the SQL.

run_sql_file <- function(file) {
  query_db(readr::read_file(here::here("sql", file)))
}

indicator_values <- function(id) {
  query_db(sprintf(
    "SELECT area_code, year_start, period, value FROM indicators WHERE indicator_id = %d", id
  ))
}

test_that("01_borough_latest.sql returns one row per London area with the latest values", {
  skip_if_not(file.exists(here::here("sql", "01_borough_latest.sql")), "sql/01_borough_latest.sql not written yet")
  out <- run_sql_file("01_borough_latest.sql")

  expect_setequal(names(out), c(
    "area_code", "area_name", "pm25", "pm25_year", "attributable_pct", "imd_score",
    "asthma_u19_rate", "asthma_u19_period", "copd_rate", "copd_period",
    "pm25_rank", "is_city_of_london"
  ))
  expect_equal(nrow(out), 33)
  expect_false(anyDuplicated(out$area_code) > 0)
  expect_true(all(startsWith(out$area_code, "E09")))

  # Latest periods
  expect_true(all(out$pm25_year == 2024))
  expect_true(all(out$asthma_u19_period == "2024/25"))
  expect_true(all(out$copd_period == "2023/24"))

  # Values match the indicators table
  pm25 <- indicator_values(93867L)
  pm25 <- pm25[pm25$year_start == 2024, ]
  expect_equal(out$pm25[order(out$area_code)], pm25$value[match(sort(out$area_code), pm25$area_code)])
  expect_equal(out$attributable_pct, 100 * (1 - 1.08^(-out$pm25 / 10)), tolerance = 1e-4)

  # Deprivation is IMD 2025 (indicator 94240), see decision D8
  imd <- indicator_values(94240L)
  expect_equal(out$imd_score, imd$value[match(out$area_code, imd$area_code)])

  # City of London: flagged, not ranked, no admissions values of its own
  city <- out[out$area_code == "E09000001", ]
  expect_true(city$is_city_of_london)
  expect_true(is.na(city$pm25_rank))
  expect_true(is.na(city$asthma_u19_rate) && is.na(city$copd_rate))
  expect_equal(sum(out$is_city_of_london), 1)

  # Ranking: 1 is the highest PM2.5 among the 32 boroughs
  ranked <- out[!out$is_city_of_london, ]
  expect_setequal(ranked$pm25_rank, 1:32)
  expect_equal(ranked$pm25_rank, rank(-ranked$pm25, ties.method = "min"))
})

test_that("02_trends.sql returns boroughs, a population-weighted London mean and England, 2018 to 2024", {
  skip_if_not(file.exists(here::here("sql", "02_trends.sql")), "sql/02_trends.sql not written yet")
  out <- run_sql_file("02_trends.sql")

  expect_setequal(names(out), c("year", "area_code", "area_name", "area_group", "pm25", "attributable_pct"))
  expect_equal(nrow(out), (33 + 1 + 1) * 7)
  expect_setequal(out$year, 2018:2024)
  expect_setequal(out$area_group, c("Borough", "London", "England"))
  expect_equal(sum(out$area_group == "Borough"), 33 * 7)

  # London rows: population-weighted mean of the 33 areas, weights from the same year
  pm25 <- indicator_values(93867L)
  af   <- indicator_values(93861L)
  pop  <- query_db("SELECT area_code, year, SUM(population) AS pop FROM population GROUP BY area_code, year")
  boroughs <- merge(
    merge(pm25[startsWith(pm25$area_code, "E09"), c("area_code", "year_start", "value")],
          af[startsWith(af$area_code, "E09"), c("area_code", "year_start", "value")],
          by = c("area_code", "year_start"), suffixes = c("_pm25", "_af")),
    pop, by.x = c("area_code", "year_start"), by.y = c("area_code", "year")
  )
  expected <- do.call(rbind, lapply(split(boroughs, boroughs$year_start), function(d) {
    data.frame(
      year = d$year_start[1],
      pm25 = sum(d$value_pm25 * d$pop) / sum(d$pop),
      attributable_pct = sum(d$value_af * d$pop) / sum(d$pop)
    )
  }))
  london <- out[out$area_group == "London", ]
  london <- london[order(london$year), ]
  expect_equal(london$pm25, expected$pm25, tolerance = 1e-8)
  expect_equal(london$attributable_pct, expected$attributable_pct, tolerance = 1e-8)

  # Sanity check against the official London figure published by Fingertips
  region <- pm25[pm25$area_code == "E12000007", ]
  region <- region[order(region$year_start), ]
  expect_lt(max(abs(london$pm25 - region$value)), 0.05)

  # England rows are the published England values
  england <- out[out$area_group == "England", ]
  eng_pm25 <- pm25[pm25$area_code == "E92000001", ]
  expect_equal(england$pm25[order(england$year)], eng_pm25$value[order(eng_pm25$year_start)])
})

test_that("03_deprivation_groups.sql splits the 32 boroughs into IMD 2025 thirds", {
  skip_if_not(file.exists(here::here("sql", "03_deprivation_groups.sql")), "sql/03_deprivation_groups.sql not written yet")
  out <- run_sql_file("03_deprivation_groups.sql")

  expect_equal(nrow(out), 3)
  expect_equal(out$imd_third, 1:3)
  expect_equal(sum(out$n_boroughs), 32)
  expect_true(all(out$year == 2024))

  # Independent calculation: City of London excluded, thirds by ascending IMD 2025
  imd  <- indicator_values(94240L)
  pm25 <- indicator_values(93867L)
  af   <- indicator_values(93861L)
  b <- data.frame(area_code = imd$area_code[startsWith(imd$area_code, "E09") & imd$area_code != "E09000001"])
  b$imd  <- imd$value[match(b$area_code, imd$area_code)]
  b$pm25 <- pm25$value[pm25$year_start == 2024][match(b$area_code, pm25$area_code[pm25$year_start == 2024])]
  b$af   <- af$value[af$year_start == 2024][match(b$area_code, af$area_code[af$year_start == 2024])]
  b$third <- dplyr::ntile(b$imd, 3)
  expected <- aggregate(cbind(pm25, af) ~ third, data = b, FUN = mean)

  expect_equal(out$n_boroughs, as.vector(table(b$third)))
  expect_equal(out$mean_pm25, expected$pm25, tolerance = 1e-10)
  expect_equal(out$mean_attributable_pct, expected$af, tolerance = 1e-10)
})
