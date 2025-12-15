# =============================================================================
# SPC Chart Generation Script
# Bruger BFHddl-pakken til at generere SPC-diagrammer
# =============================================================================

# --- Setup -------------------------------------------------------------------

# Installer BFHddl hvis ikke installeret
if (!requireNamespace("BFHddl", quietly = TRUE)) {
  message("Installerer BFHddl...")
  remotes::install_github("johanreventlow/BFHddl")
}

library(BFHddl)

# --- Konfiguration -----------------------------------------------------------

# Kopier config-template hvis config.yml ikke findes
if (!file.exists("config.yml")) {
  file.copy(
    system.file("config/config-template.yml", package = "BFHddl"),
    "config.yml"
  )
  message("config.yml oprettet - rediger den med dine stier og DSN")
  stop("Rediger config.yml og kor scriptet igen")
}

# Valider konfiguration
cfg <- get_config()
validate_config(cfg, check_paths = FALSE)

message("Konfiguration indlaest:")
message("  DSN: ", cfg$dsn)
message("  Parquet-sti: ", cfg$parquet_base_path)
message("  Output-sti: ", cfg$output_path)

# --- Database forbindelse ----------------------------------------------------

message("\nOpretter database-forbindelse...")
con <- db_connect(dsn = cfg$dsn)

# Hent datamodel
dm <- db_get_datamodel(con)

# --- Se tilgaengelige indikatorer --------------------------------------------

message("\nHenter indikatorer...")
indikatorer <- db_get_indicators(dm, active_only = TRUE)

message("Fandt ", nrow(indikatorer), " aktive indikatorer:")
# Vis tilgaengelige kolonner
message("Kolonner: ", paste(names(indikatorer), collapse = ", "))
# Vis relevante kolonner (brug indikator_navn i stedet for indikator_navn_langt)
print(indikatorer[, c("id", "indikator_navn_teknisk", "indikator_navn")])

# --- Generer diagrammer ------------------------------------------------------

# Option 1: Koer fuld pipeline for alle indikatorer
# result <- run_pipeline()

# Option 2: Koer for specifikke indikatorer
# result <- run_pipeline(
#   indicators = c("indikator_navn_1", "indikator_navn_2"),
#   format = "png"
# )

# Option 3: Dry run - se hvad der ville blive genereret
message("\n--- Dry Run ---")
plan <- run_pipeline(dry_run = TRUE, verbose = TRUE)

message("\nDry run resultat:")
message("  Indikatorer: ", length(plan$indicators_to_process))
message("  Estimerede filer: ", plan$estimated_files)

# --- Afslut ------------------------------------------------------------------

db_disconnect(con)
message("\nFaerdig!")

# =============================================================================
# Eksempler paa brug
# =============================================================================
#
# # Generer alle diagrammer som PNG
# result <- run_pipeline(format = "png")
#
# # Generer kun for specifikke indikatorer
# result <- run_pipeline(
#   indicators = c("ventetid_akut", "genindlaeggelser"),
#   format = c("png", "pdf")
# )
#
# # Generer med dato-filter
# result <- run_pipeline(
#   from_date = "2024-01-01",
#   to_date = "2024-12-31"
# )
#
# # Se status for seneste koersel
# pipeline_status()
#
# =============================================================================
