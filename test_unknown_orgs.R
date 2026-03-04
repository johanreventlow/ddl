# Test-script: Find parquet-enheder der ikke er i oversaettelsestabellen
# Med debug-output for at finde encoding/match-problemer

BFHDDL_DEV_PATH <- "c:/Users/jrev0004/OneDrive - Region Hovedstaden/4_R/BFHddl"
devtools::load_all(BFHDDL_DEV_PATH)

# Forbind til database
con <- db_connect(config_file = "config.yml")
dm <- db_get_datamodel(con)

# Hent alle kendte data-navne fra oversaettelsestabellen
known_df <- dm$OrganisationOversaettelse |>
  dplyr::select("organisatorisk_navn_fra_data") |>
  dplyr::collect()

# Hent ogsaa organisatorisk_navn_teknisk fra OrganisationStruktur
org_struktur_df <- dm$OrganisationStruktur |>
  dplyr::select("organisatorisk_navn_teknisk") |>
  dplyr::collect()

known_names_raw <- unique(c(
  known_df$organisatorisk_navn_fra_data,
  org_struktur_df$organisatorisk_navn_teknisk
))
known_names <- tolower(known_names_raw)

# Hent aktive diagrammer
diagram_data <- db_get_diagrams(dm, active_only = TRUE)
db_disconnect(con)

cfg <- get_config(file = "config.yml")
base_path <- cfg$parquet_base_path
cutoff_date <- as.Date(Sys.Date()) - 365
unique_indicators <- unique(diagram_data$indikator_navn_teknisk)

cat(sprintf("=== %d kendte navne i tblOrganisationOversaettelse ===\n", length(known_names)))
cat(sprintf("=== Scanner %d indikatorer ===\n\n", length(unique_indicators)))

all_unknown <- data.frame(indikator = character(), enhed = character(), stringsAsFactors = FALSE)
t_start <- Sys.time()

for (i_ind in seq_along(unique_indicators)) {
  ind <- unique_indicators[i_ind]
  t_ind <- Sys.time()

  ind_path <- data_get_indicator_path(ind, base_path = base_path)
  if (!dir.exists(ind_path)) {
    cat(sprintf("[%d/%d] SKIP: %s (mappe findes ikke)\n",
                i_ind, length(unique_indicators), ind))
    next
  }

  ds <- arrow::open_dataset(ind_path)
  schema_names <- tolower(names(ds))
  if (!"enhed" %in% schema_names) {
    cat(sprintf("[%d/%d] SKIP: %s (ingen enhed-kolonne)\n",
                i_ind, length(unique_indicators), ind))
    next
  }

  if ("dato" %in% schema_names) {
    ds <- ds |> dplyr::filter(.data$dato >= cutoff_date)
  }

  parquet_enheder <- ds |>
    dplyr::distinct(enhed) |>
    dplyr::collect() |>
    dplyr::pull(enhed)

  unknown <- parquet_enheder[!tolower(parquet_enheder) %in% known_names]

  if (length(unknown) > 0) {
    all_unknown <- rbind(all_unknown, data.frame(
      indikator = ind, enhed = unknown, stringsAsFactors = FALSE
    ))
  }

  elapsed <- round(as.numeric(difftime(Sys.time(), t_ind, units = "secs")), 1)
  cat(sprintf("[%d/%d] %s: %d enheder, %d ukendte (%.1fs)\n",
              i_ind, length(unique_indicators), ind,
              length(parquet_enheder), length(unknown), elapsed))
}

total_elapsed <- round(as.numeric(difftime(Sys.time(), t_start, units = "secs")), 1)
cat(sprintf("\n=== Scanning faerdig paa %.1f sekunder ===\n", total_elapsed))

cat("\n=== UKENDTE ENHEDER - DETALJERET DEBUG ===\n")
if (nrow(all_unknown) > 0) {
  for (i in seq_len(nrow(all_unknown))) {
    enhed <- all_unknown$enhed[i]
    enhed_lower <- tolower(enhed)

    # Soeg efter naermeste match i known_names (substring match)
    partial_matches <- known_names_raw[grepl(
      gsub("([[:punct:]])", "\\\\\\1", substr(enhed, 1, min(10, nchar(enhed)))),
      known_names_raw, ignore.case = TRUE
    )]

    # Vis hex-encoding for at finde encoding-forskelle
    cat(sprintf("\n[%d] Parquet enhed: \"%s\"\n", i, enhed))
    cat(sprintf("    tolower():     \"%s\"\n", enhed_lower))
    cat(sprintf("    Exact match i known_names: %s\n",
                enhed_lower %in% known_names))

    if (length(partial_matches) > 0) {
      cat(sprintf("    Delvise matches i DB:      %s\n",
                  paste(partial_matches, collapse = " | ")))
      # Sammenlign raa bytes
      for (pm in partial_matches[1:min(2, length(partial_matches))]) {
        cat(sprintf("    DB bytes:  %s\n", paste(charToRaw(pm), collapse = " ")))
        cat(sprintf("    PQ bytes:  %s\n", paste(charToRaw(enhed), collapse = " ")))
      }
    } else {
      cat("    Delvise matches i DB:      (ingen)\n")
    }
  }
} else {
  cat("Alle enheder er kendte!\n")
}
