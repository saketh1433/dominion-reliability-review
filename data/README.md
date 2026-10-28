# data/

| Folder | Contents | In git? |
|---|---|---|
| `input/` | The four reliability, meter and sales files exactly as loaded into RAW (EIA-861 2025 sheet as CSV; PUDL extracts) | Yes, all under 25 MB |
| `reference/` | Lookups: NOAA zone-to-county, EIA 2025 service territory | Yes |
| `output/` | Derived tables: `storm_index.csv` (year, storm county-days by type), `storm_vs_saidi.csv` (storm county-days and SAIDI by year), `dom_annual.csv` (EIA-930 annual peaks, floor, energy) | Yes |
| `raw/` | NOAA yearly `.csv.gz` (13 files, 139 MB) and EIA-930 six-month CSVs (17 files, 420 MB), fetched by `scripts/download_*.sh` | No, ignored |

Expected row counts for each file are in `docs/01_sources.md`. Files in this folder are not edited by hand; corrections are made in the SQL views.
