# Dominion Energy Virginia: reliability and load from public data

A reliability review of Dominion Energy Virginia built from public sources (EIA-861, NOAA Storm Events, EIA-930), loaded into Snowflake, tested and presented in Power BI.

Prepared by Saketh Bollina, October 2026. Uses no Dominion internal data and no employer systems.

## Question

Dominion's 2025 annual report shows outage minutes per customer (three-year average SAIDI, excluding major event days) rising to 133 from 130. This review tests whether the rise is explained by weather, what the weather-adjusted trend looks like, how Dominion compares with its peers and how the load on the system is changing.

## Findings

| # | Finding | Evidence | Report page |
|---|---|---|---|
| 1 | The headline figures rebuilt from EIA-861 match the annual report: 133.0 (2023 to 2025) and 130.2 (2022 to 2024). | `FCT_RELIABILITY`, customer-weighted | Scorecard |
| 2 | Storm county-days in Dominion's Virginia counties (NOAA) correlate with SAIDI ex-MED at 0.70 over 2015 to 2024. The fitted relationship predicts 145 minutes for 2025's weather. Actual: 144. | `STORM_INDEX`, `V_STORM_VS_SAIDI` | Weather |
| 3 | Weather-adjusted SAIDI ex-MED is within the noise of the fit across 2015 to 2025 (136 in 2019, 133 in 2025). Hardening to date covers under 3% of circuits, which at the stated per-circuit improvement is worth 2 to 4 minutes a year against a yearly weather swing of about 15. | `SAIDI_WEATHER_ADJUSTED` | Weather |
| 4 | Customer-weighted SAIFI ex-MED for Virginia cooperatives rose 37% from 2015 to 2025. Dominion's rose 14% over the same period and weather. | `V_GROUP_INDEX` | Weather |
| 5 | From 2019 to 2025 the highest-demand hour in the DOM zone rose 26% and the lowest rose 52%. 47 of the 50 highest-demand hours on record (July 2018 to December 2025) occurred in 2025. Smart meters are installed for 100% of customers and about 1% are on a time-varying rate. | `DOM_LOAD_ANNUAL`, `DOM_LOAD_PROFILE`, `DOM_TOP50_HOURS` | Growth |

## Architecture

```
source files (CSV) -> RAW (all VARCHAR, as published) -> STG (typed views, unpivot, de-duplication) -> MART (facts, dimensions, indexes, fits) -> tests -> Power BI
```

- RAW: one table per source file, every column VARCHAR, loaded by `COPY INTO`.
- STG: views that type, strip separators, unpivot and de-duplicate. No business logic.
- MART: business logic. Customer-weighted facts with additive numerators, a utility dimension with peer groups, the storm index, the hourly load tables, the weather fit.
- Tests T1 to T12 run after each load. Expected results are stated with each test.
- Power BI reads MART through a read-only role.

## Repository map

| Path | Content |
|---|---|
| `sql/00_look_first.sql` | Profiling queries on RAW |
| `sql/01_raw_staging.sql` | File formats, stages, RAW tables, `COPY INTO`, STG views |
| `sql/02_mart.sql` | `DIM_UTILITY`, `FCT_RELIABILITY`, `V_TREND`, `V_GROUP_INDEX` |
| `sql/03_analysis.sql` | Q1 to Q5: trend decomposition, storm share, co-op benchmark, smart meter event study, load growth |
| `sql/04_tests.sql` | T1 to T6 |
| `sql/05_noaa_storms.sql` | NOAA Storm Events to a county-day storm index, T7 to T9, Q6 |
| `sql/06_eia930_demand.sql` | EIA-930 hourly demand for the DOM zone, T10 to T12, Q7 to Q9 |
| `sql/07_weather_adjusted_and_profile.sql` | `V_STORM_VS_SAIDI`, `SAIDI_WEATHER_ADJUSTED`, `DOM_LOAD_PROFILE` |
| `sql/08_grants.sql` | Read-only role and service user for Power BI (placeholder password) |
| `scripts/` | Download scripts for NOAA and EIA-930, PUDL extraction, local DuckDB runner |
| `data/input/` | Source files as loaded (EIA-861 2025 sheet, PUDL extracts) |
| `data/reference/` | NWS zone-to-county lookup, EIA service territory |
| `data/output/` | Derived tables: storm index, storm vs SAIDI, annual load |
| `powerbi/measures.dax` | DAX measures and calculated columns |
| `powerbi/Dominion_Reliability_PowerBI_Data.xlsx` | Workbook version of the mart for use without Snowflake |
| `docs/00_conventions.md` | Naming rules |
| `docs/01_sources.md` | Source register: URLs, vintages, licences, row counts |
| `docs/02_data_dictionary.md` | Tables and columns in RAW, STG and MART |
| `docs/03_data_quality.md` | Profiling findings and tests T1 to T12 |
| `docs/04_decisions.md` | Design decisions with alternatives considered |
| `docs/05_metrics_and_measures.md` | Metric definitions and the calculation behind each dashboard figure |
| `docs/06_powerbi_report.md` | Report structure page by page |
| `docs/07_governance_and_runbook.md` | Access control, secrets, refresh procedure, change control |
| `docs/08_transformations.md` | Transformations from raw file to dashboard figure, with worked examples |

## Reproduce

1. Snowflake, X-Small warehouse. Create database `RELIABILITY` with schemas `RAW`, `STG`, `MART` (first statements of `sql/01_raw_staging.sql`).
2. Upload `data/input/*` to `EIA_STAGE` and `PUDL_STAGE`; `data/reference/*` and the NOAA files from `scripts/download_noaa.sh` to `NOAA_STAGE`; the EIA-930 files from `scripts/download_eia930.sh` to `EIA930_STAGE`.
3. Run `sql/01` to `sql/08` in order. Each file states the expected row counts.
4. Run the tests in `sql/04` and the test sections of `sql/05` and `sql/06`. Expected: T3 returns 4 rows, T5 returns 13, T8 returns 1, T10 returns 2, all others return none.
5. Set a password in `sql/08_grants.sql`, run it and connect Power BI as `POWERBI_SVC`.

Without Snowflake: `python scripts/run_local_duckdb.py` builds the reliability mart (files 01 to 04) in DuckDB from `data/input/` and prints the analysis and test results.

## Sources

| Source | Used for | Link |
|---|---|---|
| EIA-861 Annual Electric Power Industry Report, 2025 final (released 7 October 2026) | Reliability indices, customers, service territory | https://www.eia.gov/electricity/data/eia861/ (file: https://www.eia.gov/electricity/data/eia861/zip/f8612025.zip) |
| PUDL by Catalyst Cooperative, EIA-861 tables 2013 to 2024 (CC-BY 4.0) | Reliability history, meters, sales | https://docs.catalyst.coop/pudl/en/stable/data_access.html (tables `core_eia861__yearly_reliability`, `core_eia861__yearly_advanced_metering_infrastructure`, `core_eia861__yearly_sales`) |
| NOAA NCEI Storm Events Database, 2013 to 2025 | Storm county-days | https://www.ncei.noaa.gov/pub/data/swdi/stormevents/csvfiles/ |
| NWS zone-county correlation file | Forecast zone to county mapping | https://www.weather.gov/gis/ZoneCounty |
| EIA-930 Hourly Electric Grid Monitor, PJM subregion DOM, July 2018 to October 2026 | Hourly demand | https://www.eia.gov/electricity/gridmonitor/ (files: `sixMonthFiles/EIA930_SUBREGION_<year>_<half>.csv`) |
| Dominion Energy 2025 Annual Report | Figures quoted for comparison | https://s2.q4cdn.com/510812146/files/doc_downloads/2026/03/17/Dominion-Energy-2025-Annual-Report.pdf |
| Dominion Energy grid resiliency pages, Virginia SCC filings | Programme context | https://www.dominionenergy.com/projects-and-facilities/electric-projects/energy-grid-transformation/grid-resiliency-projects |

`docs/01_sources.md` lists each source with vintage, row counts, field documentation and licence. `docs/08_transformations.md` traces dashboard figures to specific rows in these files.
