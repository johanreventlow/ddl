# =============================================================================
# Diagnostik: Hvorfor fejler organisationsfiltreringen?
#
# Sammenligner organisationsnavne i tblDiagrammer (Access DB)
# med vaerdier i 'enhed'-kolonnen i parquet-filerne.
# =============================================================================

library(BFHddl)
library(DBI)
library(odbc)
library(dplyr)
library(arrow)

# --- 1. Hent konfiguration og forbind til database --------------------------

cfg <- get_config()
con <- db_connect()
dm  <- db_get_datamodel(con)

# --- 2. Hent diagrammer fra databasen ---------------------------------------

diagrams <- db_get_diagrams(dm, active_only = TRUE)

message("\n=== DIAGRAMMER FRA DATABASE ===")
message("Antal aktive diagrammer: ", nrow(diagrams))
message("\nKolonner i diagram-data:")
message("  ", paste(names(diagrams), collapse = ", "))

# Vis unikke indikator + organisation kombinationer
combos <- diagrams |>
  distinct(indikator_navn_teknisk, organisatorisk_navn_teknisk) |>
  arrange(indikator_navn_teknisk)

message("\nUnikke indikator/organisation kombinationer: ", nrow(combos))
print(combos, n = Inf)

# --- 3. Tjek parquet-filer for hver unik indikator --------------------------

message("\n=== PARQUET DATA ANALYSE ===")

unique_indicators <- unique(combos$indikator_navn_teknisk)

for (ind in unique_indicators) {
  ind_path <- file.path(cfg$parquet_base_path, ind)

  message("\n--- Indikator: ", ind, " ---")
  message("  Forventet sti: ", ind_path)

  # Tjek om mappen eksisterer
  if (!dir.exists(ind_path)) {
    message("  PROBLEM: Mappen eksisterer IKKE!")

    # Vis hvad der faktisk ligger i base path
    if (dir.exists(cfg$parquet_base_path)) {
      available <- list.dirs(cfg$parquet_base_path, recursive = FALSE, full.names = FALSE)
      # Vis de foerste 20 mapper
      message("  Tilgaengelige mapper i base path (foerste 20):")
      for (d in head(available, 20)) {
        message("    ", d)
      }
      if (length(available) > 20) {
        message("    ... og ", length(available) - 20, " mere")
      }
    } else {
      message("  PROBLEM: Base path eksisterer heller ikke: ", cfg$parquet_base_path)
    }
    next
  }

  message("  Mappe eksisterer: JA")

  # Aaben dataset og inspicer
  ds <- tryCatch(
    arrow::open_dataset(ind_path),
    error = function(e) {
      message("  PROBLEM: Kan ikke aabne dataset: ", e$message)
      NULL
    }
  )

  if (is.null(ds)) next

  # Vis kolonner
  schema_names <- names(ds)
  message("  Kolonner: ", paste(schema_names, collapse = ", "))

  # Tjek om 'enhed' kolonne eksisterer
  if (!"enhed" %in% tolower(schema_names)) {
    message("  PROBLEM: Ingen 'enhed' kolonne fundet!")
    message("  Tilgaengelige kolonner: ", paste(schema_names, collapse = ", "))
    next
  }

  # Find det faktiske kolonnenavn (case-sensitiv)
  enhed_col <- schema_names[tolower(schema_names) == "enhed"][1]

  # Hent unikke enhed-vaerdier fra parquet
  enhed_values <- ds |>
    distinct(!!sym(enhed_col)) |>
    collect() |>
    pull(!!sym(enhed_col)) |>
    sort()

  message("  Antal unikke 'enhed' vaerdier: ", length(enhed_values))
  message("  Enhed-vaerdier i parquet:")
  for (v in enhed_values) {
    message("    '", v, "'")
  }

  # Hent de forventede organisations-navne fra tblDiagrammer
  expected_orgs <- combos |>
    filter(indikator_navn_teknisk == ind) |>
    pull(organisatorisk_navn_teknisk)

  message("\n  Forventede org-navne fra tblDiagrammer:")
  for (org in expected_orgs) {
    match <- org %in% enhed_values
    status <- if (match) "MATCH" else "INGEN MATCH"
    message("    '", org, "' -> ", status)
  }

  # Vis antal raekker totalt
  total_rows <- ds |> summarise(n = n()) |> collect() |> pull(n)
  message("\n  Totalt antal raekker: ", total_rows)
}

# --- 4. Opsummering ---------------------------------------------------------

message("\n=== OPSUMMERING ===")
message("Base path: ", cfg$parquet_base_path)
message("DSN: ", cfg$dsn)
message("Antal diagrammer i DB: ", nrow(diagrams))
message("Unikke indikatorer: ", length(unique_indicators))

# --- Afslut -----------------------------------------------------------------

db_disconnect(con)
message("\n=== DIAGNOSTIK FAERDIG ===")
message("Koer dette script i RStudio for at se resultaterne.")
