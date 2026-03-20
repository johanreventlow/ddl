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

# Udviklings-mode: load fra lokal kilde uden at kompilere/installere
# unlink("C:/Users/jrev0004/OneDrive - Region Hovedstaden/ddl_output/.bfhllm_cache", recursive = TRUE)

DEV_BASE <- "c:/Users/jrev0004/OneDrive - Region Hovedstaden/4_R"

# BFHtheme foerst (dependency for BFHcharts)
BFHTHEME_DEV_PATH <- file.path(DEV_BASE, "BFHtheme")
if (dir.exists(BFHTHEME_DEV_PATH)) {
  devtools::load_all(BFHTHEME_DEV_PATH)
} else if (requireNamespace("BFHtheme", quietly = TRUE)) {
  library(BFHtheme)
}

# BFHcharts (dependency for BFHddl)
BFHCHARTS_DEV_PATH <- file.path(DEV_BASE, "BFHcharts")
if (dir.exists(BFHCHARTS_DEV_PATH)) {
  devtools::load_all(BFHCHARTS_DEV_PATH)
} else {
  library(BFHcharts)
}

# BFHllm (dependency for BFHddl batch-analyse)
BFHLLM_DEV_PATH <- file.path(DEV_BASE, "BFHllm")
if (dir.exists(BFHLLM_DEV_PATH)) {
  devtools::load_all(BFHLLM_DEV_PATH)
} else if (requireNamespace("BFHllm", quietly = TRUE)) {
  library(BFHllm)
}

# BFHddl
BFHDDL_DEV_PATH <- file.path(DEV_BASE, "BFHddl")
if (dir.exists(BFHDDL_DEV_PATH)) {
  devtools::load_all(BFHDDL_DEV_PATH)
} else {
  library(BFHddl)
}

# --- Interaktiv diagram-udvaelgelse -----------------------------------------

select_diagrams <- function(config_file = "config.yml") {
  # Forbind til database og hent data
  cfg <- get_config(config_file)
  con <- db_connect(cfg$dsn)
  on.exit(db_disconnect(con), add = TRUE)

  dm <- db_get_datamodel(con)
  diagram_data <- db_get_diagrams(dm, active_only = TRUE)
  indicator_data <- db_get_indicators(dm, active_only = FALSE,
    indicators = unique(diagram_data$indikator_navn_teknisk))

  # Join hierarki_navn, hierarki_id og indikator_navn paa diagram_data
  # Brug definition_kort som visningsnavn hvis indikator_navn ikke findes
  ind_name_col <- if ("indikator_navn" %in% names(indicator_data)) {
    "indikator_navn"
  } else if ("definition_kort" %in% names(indicator_data)) {
    "definition_kort"
  } else {
    NULL
  }

  join_cols <- intersect(
    c("indikator_navn_teknisk", "hierarki_navn", "hierarki_id", ind_name_col),
    names(indicator_data)
  )
  join_data <- indicator_data[!duplicated(indicator_data$indikator_navn_teknisk),
    join_cols, drop = FALSE]

  # Omdoeb til indikator_navn hvis vi brugte en anden kolonne
  if (!is.null(ind_name_col) && ind_name_col != "indikator_navn" &&
      ind_name_col %in% names(join_data)) {
    names(join_data)[names(join_data) == ind_name_col] <- "indikator_navn"
  }

  diagram_data <- merge(
    diagram_data,
    join_data,
    by = "indikator_navn_teknisk",
    all.x = TRUE
  )

  # --- Step 1: Vaelg hierarki (register) ---
  hierarkier <- sort(unique(diagram_data$hierarki_navn))
  valgte_hierarkier <- select.list(
    choices = c("ALLE", hierarkier),
    multiple = TRUE,
    graphics = TRUE,
    title = "Vaelg register (hierarki):"
  )

  if (length(valgte_hierarkier) == 0) {
    message("Ingen valg - afbryder")
    return(NULL)
  }

  if (!"ALLE" %in% valgte_hierarkier) {
    diagram_data <- diagram_data[diagram_data$hierarki_navn %in% valgte_hierarkier, ]
  }

  # --- Step 2: Vaelg indikatorer ---
  # Byg lookup-tabel: teknisk_navn -> visningsnavn
  ind_tekniske <- sort(unique(diagram_data$indikator_navn_teknisk))

  # Byg lookup fra teknisk -> visningsnavn med hierarki_kort, indikator_navn, teknisk
  lookup_cols <- intersect(
    c("indikator_navn_teknisk", "indikator_navn", "definition_kort",
      "hierarki_navn_kort", "hierarki_navn"),
    names(indicator_data)
  )
  ind_lookup <- indicator_data[!duplicated(indicator_data$indikator_navn_teknisk),
    lookup_cols, drop = FALSE]

  # Match til sorteret teknisk-liste
  idx <- match(ind_tekniske, ind_lookup$indikator_navn_teknisk)

  # Hierarki-kort (fallback til hierarki_navn)
  h_kort <- if ("hierarki_navn_kort" %in% names(ind_lookup)) {
    ifelse(!is.na(ind_lookup$hierarki_navn_kort[idx]) & nchar(ind_lookup$hierarki_navn_kort[idx]) > 0,
      ind_lookup$hierarki_navn_kort[idx],
      ind_lookup$hierarki_navn[idx])
  } else if ("hierarki_navn" %in% names(ind_lookup)) {
    ind_lookup$hierarki_navn[idx]
  } else {
    rep(NA_character_, length(idx))
  }

  # Indikator-navn (fallback til definition_kort)
  i_navn <- if ("indikator_navn" %in% names(ind_lookup)) {
    ind_lookup$indikator_navn[idx]
  } else if ("definition_kort" %in% names(ind_lookup)) {
    ind_lookup$definition_kort[idx]
  } else {
    rep(NA_character_, length(idx))
  }

  # Byg label: "hierarki_kort | indikator_navn (teknisk)"
  ind_labels <- vapply(seq_along(ind_tekniske), function(j) {
    parts <- character()
    if (!is.na(h_kort[j])) parts <- c(parts, h_kort[j])
    if (!is.na(i_navn[j])) parts <- c(parts, i_navn[j])
    prefix <- paste(parts, collapse = " | ")
    if (nchar(prefix) > 0) {
      paste0(prefix, " (", ind_tekniske[j], ")")
    } else {
      ind_tekniske[j]
    }
  }, character(1))

  # Vis labels, men brug tekniske navne til filtrering
  valgte_labels <- select.list(
    choices = c("ALLE", ind_labels),
    multiple = TRUE,
    graphics = TRUE,
    title = "Vaelg indikatorer:"
  )

  if (length(valgte_labels) == 0) {
    message("Ingen valg - afbryder")
    return(NULL)
  }

  if (!"ALLE" %in% valgte_labels) {
    valgte_idx <- match(valgte_labels, ind_labels)
    valgte_tekniske <- ind_tekniske[valgte_idx]
    diagram_data <- diagram_data[diagram_data$indikator_navn_teknisk %in% valgte_tekniske, ]
  }

  # --- Step 3: Vaelg organisationer ---
  organisationer <- sort(unique(diagram_data$organisatorisk_navn_teknisk))
  valgte_orgs <- select.list(
    choices = c("ALLE", organisationer),
    multiple = TRUE,
    graphics = TRUE,
    title = "Vaelg organisationer:"
  )

  if (length(valgte_orgs) == 0) {
    message("Ingen valg - afbryder")
    return(NULL)
  }

  if (!"ALLE" %in% valgte_orgs) {
    diagram_data <- diagram_data[diagram_data$organisatorisk_navn_teknisk %in% valgte_orgs, ]
  }

  message(sprintf("Valgt: %d diagrammer", nrow(diagram_data)))
  return(diagram_data)
}

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

# --- Interaktiv udvaelgelse + koersel ----------------------------------------

selected <- select_diagrams()

if (!is.null(selected) && nrow(selected) > 0) {
  result <- run_pipeline(diagram_filter = selected, format = "pdf",
                         force_refresh = TRUE, workers = 4L)
} else {
  message("Ingen diagrammer valgt - pipeline springes over")
}

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
