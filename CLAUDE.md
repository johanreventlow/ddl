# Claude Instructions – ddl

@~/.claude/rules/CLAUDE_BOOTSTRAP_WORKFLOW.md

---

## OBLIGATORISKE REGLER (KRITISK)

**ALDRIG:**
1. Merge til master/main uden eksplicit godkendelse
2. Push til remote uden anmodning
3. Tilføj Claude attribution footers

**STOP** efter feature branch commit – vent på instruktion.

---

## 1) Project Overview

- **Project Type:** R Script Runner
- **Purpose:** Kørsel af SPC-diagramgenerering via BFHddl-pakken. Simpelt interface til batch-produktion af diagrammer.
- **Status:** Under udvikling

**Technology Stack:**
- BFHddl (SPC pipeline-pakke)
- config (miljøkonfiguration)

**Dependency:** Dette projekt afhænger af BFHddl-pakken (`remotes::install_github("johanreventlow/BFHddl")`)

---

## 2) Project Structure

```
ddl/
├── run_spc_charts.R    # Hovedscript til diagramgenerering
├── config.yml          # Lokal konfiguration (miljøspecifik)
├── .gitignore          # Git ignore-regler
└── ddl.Rproj           # RStudio projekt
```

### Workflow

```
config.yml → run_spc_charts.R → BFHddl pipeline → Output (PNG/PDF)
```

### Konfiguration

`config.yml` indeholder miljøspecifikke indstillinger:
- `dsn` - ODBC Data Source Name til Access-databasen
- `parquet_base_path` - Sti til parquet-filer
- `output_path` - Sti til genererede diagrammer
- `default_format` - Output-format (png/pdf)
- `default_width/height` - Diagramdimensioner

---

## 3) Critical Constraints

### Do NOT Modify

- BFHddl-pakken direkte – opret issues i BFHddl-repo ved behov
- config.yml struktur uden at opdatere BFHddl's config-template

### Files to NEVER Commit

- `*.Rhistory`, `.RData`, `.rds`
- Credentials, passwords, connection strings
- Output-filer (PNG/PDF)
- `.Renviron`

---

## 4) Cross-Repository Coordination

### Dependencies

**ddl bruger:**
- **BFHddl** - SPC-pipeline pakke (installeres fra GitHub)

### Responsibility Boundaries

**ddl ansvar:**
- Lokal konfiguration
- Kørsel af BFHddl pipeline
- Projekt-specifik tilpasning af parametre

**BFHddl ansvar:**
- Database connection og queries
- Data loading og transformation
- Chart rendering via BFHcharts
- Pipeline orkestrering

### Communication Channel

**Ved BFHddl feature requests:**
1. Opret issue i BFHddl repo
2. Reference use case i beskrivelsen

---

## 5) Usage

```r
# Kør scriptet fra RStudio eller terminal
source("run_spc_charts.R")

# Eller fra kommandolinje
Rscript run_spc_charts.R
```

### Tilpasning

Rediger `run_spc_charts.R` for at:
- Vælge specifikke indikatorer
- Ændre output-format
- Tilføje dato-filtrering
- Køre dry run først

---

## 6) Domain-Specific Guidance

### Config Pattern

```r
# Læs konfiguration
cfg <- BFHddl::get_config()

# Valider inden brug
BFHddl::validate_config(cfg)
```

### Pipeline Pattern

```r
# Dry run først
plan <- run_pipeline(dry_run = TRUE)

# Så kør pipeline
result <- run_pipeline(
  indicators = c("indikator_1", "indikator_2"),
  format = "png"
)
```

### Danish Language

- **Script comments:** Dansk
- **Function calls:** BFHddl API (engelsk)
- **Config keys:** Engelsk

---

## Global Standards Reference

**Dette projekt følger:**
- **R Development:** `~/.claude/rules/R_STANDARDS.md`
- **Git Workflow:** `~/.claude/rules/GIT_WORKFLOW.md`
- **Development Philosophy:** `~/.claude/rules/DEVELOPMENT_PHILOSOPHY.md`
