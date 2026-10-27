# Loaded automatically by testthat before the test files run.

db_path <- here::here("data", "london_air.duckdb")

# Run a query against the project database (read-only) and return a data frame.
query_db <- function(sql) {
  con <- DBI::dbConnect(duckdb::duckdb(dbdir = db_path, read_only = TRUE, shared_home = FALSE))
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  DBI::dbGetQuery(con, sql)
}
