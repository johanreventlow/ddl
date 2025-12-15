# =============================================================================
# SPC Chart Generation Script
# Bruger BFHddl-pakken til at generere SPC-diagrammer
#
# Flowet:
# 1. Henter diagrammer fra tblDiagrammer i MS Access
# 2. For hvert diagram: indlaeser parquet data filtreret paa organisation
# 3. Genererer SPC-chart via BFHcharts
# 4. Gemmer fil: {indikator}_{organisation}_{dato}.{format}
# =============================================================================

# --- Setup -------------------------------------------------------------------

if (!requireNamespace("BFHddl", quietly = TRUE)) {
  message("Installerer BFHddl...")
  remotes::install_github("johanreventlow/BFHddl")
}

library(BFHddl)

# --- Konfiguration -----------------------------------------------------------

if (!file.exists("config.yml")) {
  file.copy(
    system.file("config/config-template.yml", package = "BFHddl"),
    "config.yml"
  )
  message("config.yml oprettet - rediger den med dine stier og DSN")
  stop("Rediger config.yml og koer scriptet igen")
}

cfg <- get_config()
validate_config(cfg, check_paths = FALSE)

message("Konfiguration:")
message("  DSN: ", cfg$dsn)
message("  Parquet: ", cfg$parquet_base_path)
message("  Output: ", cfg$output_path)

# --- Dry run - se hvad der ville blive genereret -----------------------------

message("\n--- Dry Run ---")
plan <- run_pipeline(dry_run = TRUE)

message("\nPlan:")
message("  Diagrammer: ", plan$diagrams_to_process)
message("  Unikke indikatorer: ", length(plan$indicators))
message("  Unikke organisationer: ", length(plan$organisations))
message("  Estimerede filer: ", plan$estimated_files)

# --- Koer pipeline -----------------------------------------------------------

# Uncomment en af disse for at koere:

# Normal koersel:
# result <- run_pipeline(format = "png")

# Debug mode - trin for trin:
result <- run_pipeline(debug = TRUE, format = "pdf")

# Med dato-filter:
# result <- run_pipeline(from_date = "2024-01-01", format = "png")

# Flere formater:
# result <- run_pipeline(format = c("png", "pdf"))

# --- Se status ---------------------------------------------------------------

# pipeline_status()

# =============================================================================
# API Reference
# =============================================================================
#
# run_pipeline(
#   output_dir = NULL,      # Mappe til output (fra config hvis NULL)
#   format = "png",         # "png", "pdf", eller c("png", "pdf")
#   from_date = NULL,       # Filtrer data fra denne dato
#   to_date = NULL,         # Filtrer data til denne dato
#   width = 10,             # Diagram bredde (inches)
#   height = 6,             # Diagram hoejde (inches)
#   dpi = 300,              # Oploesning for PNG
#   verbose = TRUE,         # Vis progress
#   dry_run = FALSE,        # Kun vis plan, generer ikke
#   debug = FALSE,          # Hold pause efter hvert trin
#   config_file = "config.yml"
# )
#
# pipeline_status()         # Vis seneste koersel fra log
#
# =============================================================================
