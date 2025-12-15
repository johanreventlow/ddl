# =============================================================================
# Database Exploration Script
# Udforsk Access-databasens struktur
# =============================================================================

library(DBI)
library(odbc)
library(dplyr)

# --- Forbind til database ---------------------------------------------------

cfg <- BFHddl::get_config()
con <- DBI::dbConnect(odbc::odbc(), cfg$dsn)

# --- List alle tabeller -----------------------------------------------------

message("\n=== ALLE TABELLER I DATABASEN ===\n")
tables <- DBI::dbListTables(con)
print(tables)

# --- Vis kolonner for hver tabel --------------------------------------------

message("\n=== KOLONNER PER TABEL ===\n")

for (tbl_name in tables) {
  # Spring system-tabeller over

  if (grepl("^MSys|^~", tbl_name)) next

  message("\n--- ", tbl_name, " ---")

  # Hent kolonnenavne
  cols <- DBI::dbListFields(con, tbl_name)
  message("Kolonner: ", paste(cols, collapse = ", "))

  # Vis antal rækker
  count_query <- paste0("SELECT COUNT(*) AS n FROM [", tbl_name, "]")
  n_rows <- DBI::dbGetQuery(con, count_query)$n

  message("Antal rækker: ", n_rows)
}

# --- Detaljeret visning af specifikke tabeller ------------------------------

message("\n=== DETALJERET VISNING ===\n")

# Funktion til at vise sample data
show_table <- function(con, tbl_name, n = 5) {
  message("\n>>> ", tbl_name, " (første ", n, " rækker):")
  query <- paste0("SELECT TOP ", n, " * FROM [", tbl_name, "]")
  result <- DBI::dbGetQuery(con, query)
  print(tibble::as_tibble(result))
  invisible(result)
}

# Vis de vigtigste tabeller
show_table(con, "tblIndikatorer")
show_table(con, "tblDiagrammer")
show_table(con, "tblOrganisationStruktur")

# --- Afslut -----------------------------------------------------------------

DBI::dbDisconnect(con)
message("\n=== FÆRDIG ===")
