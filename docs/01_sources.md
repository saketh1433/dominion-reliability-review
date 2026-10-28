# 01. Sources

Source register: publisher, vintage, grain, row counts loaded, licence, direct links and refresh cadence for each input.

## Source register

| # | Source | Publisher | Vintage used | Grain | Rows loaded | Licence |
|---|---|---|---|---|---|---|
| S1 | EIA-861 Reliability, 2025 final (`Reliability_2025.xlsx`, sheet `Reliability_States`) | U.S. Energy Information Administration | Released 7 Oct 2026 | utility x state x year | 977 | U.S. Government work, public domain |
| S2 | PUDL `core_eia861__yearly_reliability` | Catalyst Cooperative (cleaned EIA-861) | PUDL stable, 2013 to 2024 | utility x state x year x standard | 24,358 | CC-BY 4.0 (data), MIT (code) |
| S3 | PUDL `core_eia861__yearly_advanced_metering_infrastructure` | Catalyst Cooperative | 2013 to 2025 | utility x state x year x customer class | 127,720 | CC-BY 4.0 |
| S4 | PUDL `core_eia861__yearly_sales` | Catalyst Cooperative | 2013 to 2025 | utility x state x year x class | 198,770 | CC-BY 4.0 |
| S5 | NOAA Storm Events Database, `StormEvents_details` yearly files | NOAA NCEI | 2013 to 2025 | one row per storm event | 831,288 | U.S. Government work, public domain |
| S6 | NOAA forecast zone to county correlation (`zone_county_correlation.csv`) | NOAA NWS | Current | zone x county | 7,087 | Public domain |
| S7 | EIA-861 Service Territory 2025, sheet `Counties_States` | EIA | 2025 final | utility x state x county | 11,803 | Public domain |
| S8 | EIA-930 Hourly Demand by Subregion, six-month CSV files | EIA | July 2018 to 22 Oct 2026 | balancing authority x subregion x hour | 6,077,232 (72,864 for PJM/DOM) | Public domain |
| S9 | Dominion Energy 2025 Annual Report | Dominion Energy | Published 2026 | document | reference only | Company publication, quoted for comparison |
| S10 | Virginia SCC grid transformation filings, Dominion grid resiliency pages | Virginia State Corporation Commission, Dominion Energy | 2025 to 2026 | document | reference only | Public filings |

## Where each file lives in this repository

| Source | Path | Committed | Note |
|---|---|---|---|
| S1 | `data/input/Reliability_2025_States.csv` | Yes (144 KB) | File as loaded |
| S2 | `data/input/pudl_reliability_2013_2024.csv` | Yes (2.9 MB) | Extract from PUDL parquet, see `scripts/extract_pudl.py` |
| S3 | `data/input/pudl_ami.csv` | Yes (12 MB) | Same |
| S4 | `data/input/pudl_sales.csv` | Yes (23 MB) | Same |
| S5 | not committed (139 MB gzipped) | No | `scripts/download_noaa.sh` fetches the 13 files. File names carry a creation stamp (`_c20260323`) that changes when NOAA re-issues a file; the script reads the directory listing |
| S6 | `data/reference/zone_county_correlation.csv` | Yes | Lookup |
| S7 | `data/reference/Service_Territory_2025_Counties_States.csv` | Yes | Lookup |
| S8 | not committed (420 MB) | No | `scripts/download_eia930.sh` fetches the 17 files |
| S9, S10 | not committed | No | Copyrighted documents. Page references are given where a figure is quoted |

## Direct links

Landing page, file used, field documentation and licence for each source.

| Source | Landing page | File used | Field definitions | Licence |
|---|---|---|---|---|
| S1, S7 EIA-861 2025 final | https://www.eia.gov/electricity/data/eia861/ (release date stated there: 7 October 2026, final data) | https://www.eia.gov/electricity/data/eia861/zip/f8612025.zip (contains `Reliability_2025.xlsx` and `Service_Territory_2025.xlsx`) | Form and instructions: https://www.eia.gov/survey/#eia-861 . Guide to EIA electric power data: https://www.eia.gov/electricity/data/guide/ | U.S. Government work, public domain |
| S2, S3, S4 PUDL | https://catalyst.coop/pudl/ . Data access page: https://docs.catalyst.coop/pudl/en/stable/data_access.html | Stable parquet, bucket `s3://pudl.catalyst.coop/stable/`, for example https://s3.us-west-2.amazonaws.com/pudl.catalyst.coop/stable/core_eia861__yearly_reliability.parquet (also `core_eia861__yearly_advanced_metering_infrastructure.parquet` and `core_eia861__yearly_sales.parquet`). Browse without code at https://data.catalyst.coop | EIA-861 source notes: https://docs.catalyst.coop/pudl/en/latest/data_sources/eia861.html . Data dictionary: https://docs.catalyst.coop/pudl/en/latest/data_dictionaries/pudl_db.html | CC-BY 4.0 (data), listed in the AWS Open Data Registry: https://registry.opendata.aws/catalyst-cooperative-pudl/ |
| S5 NOAA Storm Events | https://www.ncei.noaa.gov/stormevents/ | Bulk directory https://www.ncei.noaa.gov/pub/data/swdi/stormevents/csvfiles/ . Files used: `StormEvents_details-ftp_v1.0_d2013_c20260323.csv.gz` through `d2025_c20260819.csv.gz` (13 files; the `_c` stamp changes when NOAA re-issues a year) | `Storm-Data-Bulk-csv-Format.pdf` and `Storm-Data-Export-Format.pdf` in the same directory | U.S. Government work, public domain |
| S6 NWS zone-county correlation | https://www.weather.gov/gis/ZoneCounty | The pipe-delimited correlation file published there (`bp16ap26.dbx` as of October 2026). `data/reference/zone_county_correlation.csv` is the same table as CSV | Column list on the same page: STATE, ZONE, CWA, NAME, STATE_ZONE, COUNTY, FIPS, TIME_ZONE, FE_AREA, LAT, LON | Public domain |
| S8 EIA-930 hourly demand | https://www.eia.gov/electricity/gridmonitor/ | Six-month subregion files, pattern https://www.eia.gov/electricity/gridmonitor/sixMonthFiles/EIA930_SUBREGION_2025_Jan_Jun.csv (17 files, 2018 Jul_Dec to 2026 Jul_Dec; `scripts/download_eia930.sh`) | About the data: https://www.eia.gov/electricity/930-content/about.html | U.S. Government work, public domain |
| S9 Dominion Energy 2025 Annual Report | https://investors.dominionenergy.com/ | https://s2.q4cdn.com/510812146/files/doc_downloads/2026/03/17/Dominion-Energy-2025-Annual-Report.pdf . The SEC-filed annual report (Form ARS) is at https://www.sec.gov/Archives/edgar/data/715957/000119312526115192/dei-ars-12312025.pdf and the 10-K at https://www.sec.gov/Archives/edgar/data/715957/000119312526063120/d-20251231.htm | Page references are given wherever a figure is quoted (133 and 130 on page 10, the 38-of-50 peak statement, winter peak, customers 2,809k) | Company publication, quoted for comparison only |
| S10 Dominion grid resiliency materials | https://www.dominionenergy.com/projects-and-facilities/electric-projects/energy-grid-transformation/grid-resiliency-projects | Same page and its FAQ | Hardening and undergrounding figures quoted in `docs/04_decisions.md` D14 | Company publication |
| S10 Virginia SCC filings | https://www.scc.virginia.gov/ , case documents through the SCC docket search | Grid transformation plan filings and annual reliability reports by case number | | Public filings |

To verify a figure: open the file at the link, locate the row identified in `docs/08_transformations.md` (line numbers for EIA-930 rows, event IDs for NOAA rows) and compare it with the value quoted there.

## How to re-download

```bash
scripts/download_noaa.sh      # 13 files into data/raw/noaa/
scripts/download_eia930.sh    # 17 files into data/raw/eia930/
python scripts/extract_pudl.py   # rewrites data/input/pudl_*.csv from PUDL parquet
```

EIA-861 2025 (S1, S7): download https://www.eia.gov/electricity/data/eia861/zip/f8612025.zip, open `Reliability_2025.xlsx` and `Service_Territory_2025.xlsx` and save the named sheets as CSV. The Reliability sheet has three header rows and uses "." for blanks; file format `FF_EIA_CSV` handles both (`SKIP_HEADER = 3`, `NULL_IF = ('.')`).

## Refresh cadence

| Source | Refresh cadence | What to re-run |
|---|---|---|
| EIA-861 | Annual, final data each October for the prior year | 01, 02, 04, then 03 |
| PUDL | Follows EIA releases, typically a few weeks after | `extract_pudl.py`, then 01, 02, 04 |
| NOAA Storm Events | Monthly, with a lag of about 90 days. Files are re-issued (new `_c` stamp) when events are revised | 05 |
| EIA-930 | Daily. Subregion data lags 1 to 30 days | 06, 07 |

## Field provenance of the headline figures

| Dashboard figure | Source | Fields | Transformation |
|---|---|---|---|
| 133.0 (three-year SAIDI, 2023 to 2025) | S1, S2 | `oth_saidi_ex_med`, `oth_customers` (2025); PUDL `saidi_ex_med`, `customers` (2023, 2024) | Customer-minutes summed per year, divided by customers, averaged over three years |
| 53% storm share 2025 | S1 | `oth_saidi_all`, `oth_saidi_ex_med` | (306.7 - 144.4) / 306.7 |
| 0.70 correlation, 145 predicted | S5, S6, S7, S1, S2 | `event_type`, `cz_type`, `cz_fips`, `begin_yearmonth`, `begin_day` -> county-days; SAIDI ex MED | OLS fit of SAIDI on storm county-days, 2015 to 2024 |
| 137 vs 114 co-op index | S1, S2 | all Virginia cooperatives, customer-weighted | Each year / 2015 x 100 |
| +52% base load, +26% peak | S8 | `Demand (MW)` for `PJM` / `DOM` | Min and max hour per calendar year, 2025 / 2019 |
| 47 of 50 | S8 | same | Rank all hours to 31 Dec 2025, count top 50 by year |
| 165 / 108 sales index | S4 | `sales_mwh`, `customers` by class | Each year / 2013 x 100 |
| 1% on time-varying rate | S3 and EIA-861 Dynamic Pricing | `advanced_metering_infrastructure`, time-based rate customers | Share of customers |

## Attribution text for the dashboard

"Sources: U.S. EIA Form 861 (2025 final), PUDL by Catalyst Cooperative (CC-BY 4.0), NOAA NCEI Storm Events Database, U.S. EIA Form 930. Dominion Energy 2025 Annual Report quoted for comparison."
