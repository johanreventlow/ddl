# Design: Interaktiv diagram-udvælgelse

**Dato:** 2026-03-02
**Status:** Godkendt

## Problem

Pipeline kører alle 9 diagrammer fra tblDiagrammer uden mulighed for at vælge specifikke. Brugeren har brug for at kunne udvælge præcist hvilke PDF-filer der genereres.

## Løsning: Tilgang A — Wrapper i ddl + minimalt filter i BFHddl

### Ændring 1: `run_pipeline()` i BFHddl

Nyt argument `diagram_filter` (default `NULL`):
- `NULL` = hent alle diagrammer fra DB (nuværende adfærd)
- Tibble = brug direkte som `diagram_data`, spring Fase 3 over

### Ændring 2: `select_diagrams()` i ddl/run_spc_charts.R

Interaktiv funktion med tre `select.list()` trin:

1. **Hierarki** — vælg registre (fx "Dansk Anæstesi Database"). "ALLE" som første valg.
2. **Indikator** — vælg indikatorer filtreret på valgte hierarkier. "ALLE" som første valg.
3. **Organisation** — vælg organisationer filtreret på valgte indikatorer. "ALLE" som første valg.

Returnerer filtreret `diagram_data` tibble.

### Flow

```
select_diagrams()
  ├─ Forbind til DB, hent diagram_data + indicator_data
  ├─ Step 1: select.list(hierarkier, multiple = TRUE)
  ├─ Step 2: select.list(indikatorer, multiple = TRUE)
  ├─ Step 3: select.list(organisationer, multiple = TRUE)
  └─ Return: filtreret diagram_data (tibble)

run_pipeline(diagram_filter = selected_data, format = "pdf")
  └─ Bruger diagram_filter i stedet for DB-hentning
```

### Brug

```r
selected <- select_diagrams()
result <- run_pipeline(diagram_filter = selected, format = "pdf")
```

### Afgrænsning

- `select_diagrams()` bor i ddl-projektet, ikke i BFHddl-pakken
- `run_pipeline()` ændres minimalt: accepter `diagram_filter`, spring Fase 3 over hvis sat
- Ingen nye dependencies (select.list() er base R)
