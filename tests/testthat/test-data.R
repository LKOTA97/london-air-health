# Data checks on the DuckDB tables built by R/04_build_db.R.

test_that("every indicator has all 33 London areas in its latest period", {
  latest <- query_db("
    WITH latest AS (
      SELECT indicator_id, MAX(year_start) AS year_start
      FROM indicators
      GROUP BY indicator_id
    )
    SELECT i.indicator_id, COUNT(DISTINCT i.area_code) AS n_london
    FROM indicators AS i
    JOIN latest AS l
      ON i.indicator_id = l.indicator_id AND i.year_start = l.year_start
    WHERE i.area_code LIKE 'E09%'
    GROUP BY i.indicator_id
  ")
  expect_equal(nrow(latest), 8)
  expect_true(all(latest$n_london == 33))
})

test_that("there is one row per area, indicator, period, sex and age", {
  dupes <- query_db("
    SELECT area_code, indicator_id, period, sex, age, COUNT(*) AS n
    FROM indicators
    GROUP BY area_code, indicator_id, period, sex, age
    HAVING COUNT(*) > 1
  ")
  expect_equal(nrow(dupes), 0)
})

test_that("PM2.5 and attributable fractions are in plausible ranges", {
  pm25 <- query_db("SELECT value FROM indicators WHERE indicator_id = 93867")$value
  af   <- query_db("SELECT value FROM indicators WHERE indicator_id = 93861")$value
  expect_false(anyNA(pm25))
  expect_false(anyNA(af))
  expect_true(all(pm25 >= 3 & pm25 <= 20))
  expect_true(all(af >= 2 & af <= 12))
})

test_that("Fingertips 93861 equals 100 * (1 - 1.08^(-C/10)) for every London area and year", {
  # Ties the model's hazard ratio (1.08 per 10 ug/m3, COMEAP 2022, no cut-off)
  # to the official statistic.
  check <- query_db("
    SELECT c.area_code, c.year_start, c.value AS pm25, a.value AS attributable_pct
    FROM indicators AS c
    JOIN indicators AS a
      ON c.area_code = a.area_code AND c.year_start = a.year_start
    WHERE c.indicator_id = 93867
      AND a.indicator_id = 93861
      AND c.area_code LIKE 'E09%'
  ")
  expect_equal(nrow(check), 33 * 7)
  formula <- 100 * (1 - 1.08^(-check$pm25 / 10))
  expect_lt(max(abs(check$attributable_pct - formula)), 0.01)
})

test_that("City of London admissions are blank and flagged as combined with Hackney", {
  admissions <- query_db("
    SELECT area_code, value, value_note
    FROM indicators
    WHERE indicator_id IN (90810, 92302)
      AND area_code IN ('E09000001', 'E09000012')
  ")
  city    <- admissions[admissions$area_code == "E09000001", ]
  hackney <- admissions[admissions$area_code == "E09000012", ]
  expect_true(all(is.na(city$value)))
  expect_false(anyNA(hackney$value))
  expect_true(all(grepl("Hackney and City of London combined", hackney$value_note)))
})

test_that("areas holds 33 London areas, the London region and England", {
  areas <- query_db("SELECT * FROM areas")
  expect_equal(nrow(areas), 35)
  expect_equal(sum(areas$is_london), 33)
  expect_equal(areas$area_code[areas$is_city_of_london], "E09000001")
  expect_setequal(areas$area_code[!areas$is_london], c("E12000007", "E92000001"))
})

test_that("population has every area, sex and single year of age for 2018 to 2025", {
  pop <- query_db("
    SELECT year, COUNT(DISTINCT area_code) AS n_areas, COUNT(*) AS n_rows,
           MIN(age) AS min_age, MAX(age) AS max_age, MIN(population) AS min_pop
    FROM population
    GROUP BY year
    ORDER BY year
  ")
  expect_equal(pop$year, 2018:2025)
  expect_true(all(pop$n_areas == 33))
  expect_true(all(pop$n_rows == 33 * 2 * 91))
  expect_true(all(pop$min_age == 0 & pop$max_age == 90))
  expect_true(all(pop$min_pop >= 0))
})

test_that("area codes agree across indicators, population and boundaries", {
  london_areas <- query_db("SELECT area_code FROM areas WHERE is_london")$area_code
  pop_areas    <- query_db("SELECT DISTINCT area_code FROM population")$area_code
  boundaries   <- sf::st_read(here::here("data", "clean", "london_boundaries.geojson"), quiet = TRUE)
  expect_setequal(pop_areas, london_areas)
  expect_setequal(boundaries$area_code, london_areas)
})

test_that("life table covers ages 0 to 100 for both sexes with valid probabilities", {
  lt <- query_db("SELECT sex, age, mx, qx FROM life_table")
  expect_equal(nrow(lt), 2 * 101)
  expect_setequal(lt$age, 0:100)
  expect_true(all(lt$qx > 0 & lt$qx < 1))
  expect_true(all(lt$mx > 0))
})

test_that("utility norms cover ages 30 to 100 for both versions and sexes and lie between 0 and 1", {
  u <- query_db("SELECT version, sex, age, utility FROM utility_norms")
  expect_setequal(unique(u$version), c("EQ-5D-5L", "EQ-5D-3L"))
  for (v in c("EQ-5D-5L", "EQ-5D-3L")) for (s in c("Female", "Male")) {
    expect_true(all(30:100 %in% u$age[u$version == v & u$sex == s]))
  }
  expect_true(all(u$utility > 0 & u$utility <= 1))
})

test_that("utility norms match the published examples", {
  u <- query_db("SELECT version, sex, age, utility FROM utility_norms WHERE age = 30")
  get <- function(v, s) round(u$utility[u$version == v & u$sex == s], 3)
  # EEPRU Report 082 spreadsheet, sheet Predictions
  expect_equal(get("EQ-5D-5L", "Male"), 0.935)
  expect_equal(get("EQ-5D-5L", "Female"), 0.912)
  # NICE DSU 2022 report, Table 1, HSE 2014 column
  expect_equal(get("EQ-5D-3L", "Male"), 0.923)
  expect_equal(get("EQ-5D-3L", "Female"), 0.904)
})
