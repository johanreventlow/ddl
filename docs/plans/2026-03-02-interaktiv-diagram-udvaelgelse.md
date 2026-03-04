# Interaktiv Diagram-Udvælgelse Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Tilføj interaktiv multi-niveau udvælgelse af diagrammer før pipeline kører, via `select.list()`.

**Architecture:** Ny `select_diagrams()` funktion i ddl/run_spc_charts.R forbinder til DB, viser 3 `select.list()` trin (hierarki → indikator → organisation), og returnerer filtreret diagram_data. `run_pipeline()` i BFHddl får nyt `diagram_filter` argument der springer Fase 3 over.

**Tech Stack:** Base R (`select.list()`), BFHddl (db_connect, db_get_datamodel, db_get_diagrams, db_get_indicators, db_disconnect)

---

## Task 1: Tilføj `diagram_filter` argument til `run_pipeline()`

**Files:**
- Modify: `C:/Users/jrev0004/OneDrive - Region Hovedstaden/4_R/BFHddl/R/pipeline.R:43-53` (funktionssignatur)
- Modify: `C:/Users/jrev0004/OneDrive - Region Hovedstaden/4_R/BFHddl/R/pipeline.R:183-228` (Fase 3 logik)

**Step 1: Tilføj `diagram_filter` parameter til funktionssignaturen**

I `pipeline.R` linje 43-53, tilføj `diagram_filter = NULL` som parameter:

```r
run_pipeline <- function(output_dir = NULL,
                         format = "png",
                         from_date = NULL,
                         to_date = NULL,
                         width = 10,
                         height = 6,
                         dpi = 300,
                         verbose = TRUE,
                         dry_run = FALSE,
                         debug = FALSE,
                         diagram_filter = NULL,
                         config_file = "config.yml") {
```

**Step 2: Modificer Fase 3 til at bruge `diagram_filter` hvis den er sat**

Erstat Fase 3 blokken (linje 183-228) så den springer DB-hentning over hvis `diagram_filter` er en tibble:

```r
  # ==========================================================================
  # FASE 3: HENT DIAGRAMMER
  # ==========================================================================
  cli::cli_rule("Fase 3: Hent diagrammer fra tblDiagrammer")

  if (!is.null(diagram_filter) && is.data.frame(diagram_filter)) {
    # Brug eksternt filtreret diagram_data
    diagram_data <- diagram_filter
    log_step("3.1", "Bruger eksternt filtreret diagrammer: {nrow(diagram_data)} stk")
  } else {
    # Hent fra database (nuvaerende adfaerd)
    log_step("3.1", "Henter aktive diagrammer...")
    diagram_data <- db_get_diagrams(dm, active_only = TRUE)
  }

  log_detail("Antal diagrammer", nrow(diagram_data))

  if (nrow(diagram_data) == 0) {
    cli::cli_abort("Ingen aktive diagrammer fundet i tblDiagrammer")
  }

  # Vis detaljer om diagrammer
  unique_indicators <- unique(diagram_data$indikator_navn_teknisk)
  unique_orgs <- unique(diagram_data$organisatorisk_navn_teknisk)

  log_detail("Unikke indikatorer", length(unique_indicators))
  log_detail("Unikke organisationer", length(unique_orgs))

  if (debug) {
    cli::cli_h3("Indikatorer:")
    cli::cli_bullets(setNames(unique_indicators, rep("*", length(unique_indicators))))

    cli::cli_h3("Organisationer:")
    cli::cli_bullets(setNames(unique_orgs, rep("*", length(unique_orgs))))
  }

  debug_pause()

  # 3.2 Hent indikator-metadata
  log_step("3.2", "Henter indikator-metadata...")

  indicator_data <- db_get_indicators(dm, active_only = FALSE, indicators = unique_indicators)

  log_detail("Indikatorer med metadata", nrow(indicator_data))

  if (debug && nrow(indicator_data) > 0) {
    cli::cli_h3("Indikator-kolonner:")
    cli::cli_bullets(setNames(names(indicator_data), rep(" ", length(names(indicator_data)))))
  }

  log_success("Fase 3 faerdig: {nrow(diagram_data)} diagrammer klar")
  debug_pause()
```

**Step 3: Test at pipeline stadig virker uden `diagram_filter`**

Kør fra RStudio i ddl-projektet:
```r
devtools::load_all("c:/Users/jrev0004/OneDrive - Region Hovedstaden/4_R/BFHddl")
plan <- run_pipeline(dry_run = TRUE)
```
Forventet: Samme output som før (9 diagrammer).

---

## Task 2: Skriv `select_diagrams()` i run_spc_charts.R

**Files:**
- Modify: `c:/Users/jrev0004/OneDrive - Region Hovedstaden/4_R/ddl/run_spc_charts.R`

**Step 1: Tilføj `select_diagrams()` funktionen**

Tilføj denne funktion efter setup-sektionen (efter linje 26), før konfigurationssektionen:

```r
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

  # Join hierarki_navn paa diagram_data
  diagram_data <- merge(
    diagram_data,
    indicator_data[, c("indikator_navn_teknisk", "hierarki_navn")],
    by = "indikator_navn_teknisk",
    all.x = TRUE
  )

  # --- Step 1: Vaelg hierarki (register) ---
  hierarkier <- sort(unique(diagram_data$hierarki_navn))
  valgte_hierarkier <- select.list(
    choices = c("ALLE", hierarkier),
    multiple = TRUE,
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
  indikatorer <- sort(unique(diagram_data$indikator_navn_teknisk))
  valgte_indikatorer <- select.list(
    choices = c("ALLE", indikatorer),
    multiple = TRUE,
    title = "Vaelg indikatorer:"
  )

  if (length(valgte_indikatorer) == 0) {
    message("Ingen valg - afbryder")
    return(NULL)
  }

  if (!"ALLE" %in% valgte_indikatorer) {
    diagram_data <- diagram_data[diagram_data$indikator_navn_teknisk %in% valgte_indikatorer, ]
  }

  # --- Step 3: Vaelg organisationer ---
  organisationer <- sort(unique(diagram_data$organisatorisk_navn_teknisk))
  valgte_orgs <- select.list(
    choices = c("ALLE", organisationer),
    multiple = TRUE,
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
```

**Step 2: Opdater hovedscriptet til at bruge `select_diagrams()`**

Erstat den nuvaerende pipeline-koersel sektion (linje 47-66) med:

```r
# --- Interaktiv udvaelgelse + koersel ----------------------------------------

selected <- select_diagrams()

if (!is.null(selected) && nrow(selected) > 0) {
  result <- run_pipeline(diagram_filter = selected, format = "pdf")
} else {
  message("Ingen diagrammer valgt - pipeline springes over")
}
```

---

## Task 3: Manuel test i RStudio

**Step 1: Source og test**

Abn `run_spc_charts.R` i RStudio og source det. Forventet flow:

1. BFHddl loades via `devtools::load_all()`
2. Config valideres
3. `select_diagrams()` aabner 3 dialog-vinduer:
   - Vaelg register → fx "Dansk Anaestesi Database"
   - Vaelg indikatorer → viser kun indikatorer fra valgte register
   - Vaelg organisationer → viser kun organisationer fra valgte indikatorer
4. Pipeline koerer kun for valgte diagrammer

**Step 2: Test ALLE-valg**

Source igen, vaelg "ALLE" i step 1. Forventet: Alle 9 diagrammer processeres (ingen filtrering).

**Step 3: Test afbryd (ingen valg)**

Source igen, luk dialog uden valg. Forventet: "Ingen diagrammer valgt - pipeline springes over".
