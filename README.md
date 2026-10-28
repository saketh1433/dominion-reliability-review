# Dominion Energy Virginia: reliability and load, rebuilt from public data

An independent reliability review of Dominion Energy Virginia built entirely from public sources (EIA-861, NOAA Storm Events, EIA-930), loaded into Snowflake, tested and presented in Power BI.

Prepared by Saketh Bollina, October 2026, as an independent analysis of Dominion Energy Virginia's published reliability record. Nothing here uses Dominion internal data or any employer's systems.

## The question

Dominion's 2025 annual report shows outage minutes per customer rising to 133 (three-year average) from 130. Was that the grid or the weather and what sits underneath it?

## The answer, in five findings

| # | Finding | Evidence | Where |
|---|---|---|---|
| 1 | The headline number rebuilt from EIA-861 ties to the annual report to the decimal (133.0, 130.2). | `FCT_RELIABILITY`, customer-weighted | Scorecard page |
| 2 | 2025 was the weather. NOAA storm days in Dominion's counties predict the day-to-day number at correlation 0.70 and predict 145 minutes for 2025's weather. Actual: 144. | `STORM_INDEX`, `V_STORM_VS_SAIDI` | Weather page |
| 3 | Remove the weather and the underlying number has not moved since 2015 (136 in 2019, 133 in 2025). Expected: hardening covers under 3% of circuits, worth 2 to 4 minutes against a 15-minute yearly weather swing. The annual metric cannot see the programme yet. | `SAIDI_WEATHER_ADJUSTED` | Weather page |
| 4 | On the same weather, outage frequency at Virginia's co-ops rose 37% since 2015. Dominion's rose 14%. | `V_GROUP_INDEX` | Weather page |
| 5 | Load is growing fastest at night. 2019 to 2025 the busiest hour rose 26%, the quietest rose 52%. 47 of the 50 highest-load hours on record fell in 2025. Smart meters are 100% installed and about 1% of customers are on a rate that uses them. | `DOM_LOAD_ANNUAL`, `DOM_LOAD_PROFILE`, `DOM_TOP50_HOURS` | Growth page |

## How it is built

```
sources (CSV) -> RAW (all VARCHAR, as filed) -> STG (typed views, dedupe, unpivot) -> MART (facts, dims, indexes) -> tests -> Power BI
```

- **RAW** keeps every file exactly as published, every column text. Nothing is lost at load.
- **STG** types, cleans and reshapes. No business logic.
- **MART** holds the business logic once: customer-weighted facts with additive numerators, the dimension with peer groups, the storm index, the hourly load tables.
- **Tests** (T1 to T12) run after every load and return zero rows when the data is sound.
- **Power BI** reads MART only, through a read-only role.

Full detail in `docs/`.

## Repository map

| Path | What it holds |
|---|---|
| `sql/00_look_first.sql` | Profiling queries run on RAW before anything was typed |
| `sql/01_raw_staging.sql` | File formats, stages, RAW tables, COPY INTO, STG views |
| `sql/02_mart.sql` | `DIM_UTILITY`, `FCT_RELIABILITY`, `V_TREND`, `V_GROUP_INDEX` |
| `sql/03_analysis.sql` | Q1 to Q5: trend decomposition, storm share, co-op benchmark, smart meter event study, load growth |
| `sql/04_tests.sql` | T1 to T6 on the reliability mart |
| `sql/05_noaa_storms.sql` | NOAA Storm Events to a county-day storm index, T7 to T9, Q6 |
| `sql/06_eia930_demand.sql` | EIA-930 hourly demand for the DOM zone, T10 to T12, Q7 to Q9 |
| `sql/07_weather_adjusted_and_profile.sql` | `V_STORM_VS_SAIDI`, `SAIDI_WEATHER_ADJUSTED`, `DOM_LOAD_PROFILE` |
| `sql/08_grants.sql` | Read-only role and service user for Power BI (no secrets in the file) |
| `scripts/` | Download scripts for the large sources, PUDL extraction, local DuckDB runner |
| `data/input/` | Small source files committed as used (EIA-861 2025, PUDL extracts) |
| `data/reference/` | Lookups: NOAA zone-to-county, EIA service territory |
| `data/output/` | Derived outputs small enough to commit, for anyone who wants the numbers without Snowflake |
| `powerbi/measures.dax` | Every DAX measure in the report, with its business name |
| `powerbi/Dominion_Reliability_PowerBI_Data.xlsx` | Workbook version of the mart for the no-Snowflake route |
| `docs/00_conventions.md` | Every naming rule in the repository, Snowflake and Power BI |
| `docs/01_sources.md` | Every source: URL, vintage, licence, row counts, how to re-download |
| `docs/02_data_dictionary.md` | Every table and column in RAW, STG and MART |
| `docs/03_data_quality.md` | The twelve tests, what each found, what was done about it |
| `docs/04_decisions.md` | The judgement calls, each with the alternative considered |
| `docs/05_metrics_and_measures.md` | SAIDI, SAIFI, CAIDI explained and how each dashboard number is computed |
| `docs/06_powerbi_report.md` | The report page by page |
| `docs/07_governance_and_runbook.md` | Roles, secrets, refresh procedure, change control |
| `docs/08_transformations.md` | From the raw cell to the dashboard number: every cleaning rule, with five worked examples on real rows |

## Reproduce it

1. Snowflake, any edition, X-Small warehouse. Create database `RELIABILITY` with schemas `RAW`, `STG`, `MART` (first statements of `sql/01_raw_staging.sql`).
2. Upload `data/input/*` to `EIA_STAGE` and `PUDL_STAGE`, `data/reference/*` plus the NOAA files from `scripts/download_noaa.sh` to `NOAA_STAGE`, the EIA-930 files from `scripts/download_eia930.sh` to `EIA930_STAGE`.
3. Run `sql/01` through `sql/08` in order. Each file states the row counts to expect.
4. Run `sql/04_tests.sql` plus the test sections of 05 and 06. Expected: T3 returns 4 rows, T5 returns 13, T8 returns 1, T10 returns 2, everything else returns none.
5. Run `sql/08_grants.sql` with your own password, then connect Power BI as `POWERBI_SVC`.

Without Snowflake: `python scripts/run_local_duckdb.py` builds the core mart (01 to 04) in DuckDB from `data/input/` and prints the analysis and test results.

## Sources and verification

| Source | Used for | Direct link |
|---|---|---|
| EIA-861 Annual Electric Power Industry Report, 2025 final (released 7 October 2026) | Reliability indices, customers, service territory | https://www.eia.gov/electricity/data/eia861/ (file: https://www.eia.gov/electricity/data/eia861/zip/f8612025.zip) |
| PUDL by Catalyst Cooperative, EIA-861 tables 2013 to 2024 (CC-BY 4.0) | Reliability history, meters, sales | https://docs.catalyst.coop/pudl/en/stable/data_access.html (table `core_eia861__yearly_reliability` and two others) |
| NOAA NCEI Storm Events Database, 2013 to 2025 | Storm county-days | https://www.ncei.noaa.gov/pub/data/swdi/stormevents/csvfiles/ |
| NWS zone-county correlation file | Mapping forecast zones to counties | https://www.weather.gov/gis/ZoneCounty |
| EIA-930 Hourly Electric Grid Monitor, PJM subregion DOM, July 2018 to October 2026 | Hourly demand | https://www.eia.gov/electricity/gridmonitor/ (files: `sixMonthFiles/EIA930_SUBREGION_<year>_<half>.csv`) |
| Dominion Energy 2025 Annual Report | Figures quoted for comparison | https://s2.q4cdn.com/510812146/files/doc_downloads/2026/03/17/Dominion-Energy-2025-Annual-Report.pdf |
| Dominion Energy grid resiliency pages, Virginia SCC filings | Programme context | https://www.dominionenergy.com/projects-and-facilities/electric-projects/energy-grid-transformation/grid-resiliency-projects |

Every number on the dashboard can be traced to a row in one of these files. `docs/08_transformations.md` walks the chain with the actual rows (the Dominion line in the EIA sheet, five NOAA event IDs for one Chesterfield storm, line 171,407 of an EIA-930 file). `docs/01_sources.md` has the full register with vintages, row counts, field documentation and licences.
