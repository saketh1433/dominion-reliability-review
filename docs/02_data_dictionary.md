# 02. Data dictionary

Database `RELIABILITY`, three schemas. The contract between them:

| Schema | Rule | Who writes | Who reads |
|---|---|---|---|
| `RAW` | Every column `VARCHAR`. One table per source file, loaded by `COPY INTO`. Never edited after load. | the load scripts | `STG` only |
| `STG` | Views. Typing (`TRY_TO_NUMBER`, `TRY_TO_DATE`), thousands separators stripped, unpivot, de-duplication. No business logic. | `01`, `05`, `06` | `MART` only |
| `MART` | Tables and views with the business logic: keys, peer groups, additive numerators, indexes, fits. | `02`, `05`, `06`, `07` | Power BI (`BI_READER`), analysts |

Grain is stated for every object. A utility is identified throughout by `utility_key = utility_id || '|' || state`, because EIA reports one row per utility per state and a utility that operates in two states is two reporting units.

## RAW

### `RAW.EIA861_RELIABILITY_2025` (977 rows, one per utility-state, 2025)
Sheet `Reliability_States` of EIA's `Reliability_2025.xlsx`. The sheet has two blocks side by side: utilities that report under IEEE 1366 fill the `ieee_*` columns, utilities with their own major-event rule fill the `oth_*` columns.

| Column | Meaning |
|---|---|
| `data_year`, `utility_number`, `utility_name`, `state`, `ownership` | Identity. `ownership` is EIA's entity type (Investor Owned, Cooperative, Municipal, ...) |
| `ieee_saidi_all`, `ieee_saifi_all`, `ieee_caidi_all` | All events, IEEE 1366 filers |
| `ieee_saidi_ex_med`, `ieee_saifi_ex_med`, `ieee_caidi_ex_med` | Excluding major event days (IEEE 1366 2.5 beta method) |
| `ieee_saidi_los`, `ieee_saifi_los`, `ieee_caidi_los` | Excluding loss-of-supply events |
| `ieee_customers`, `ieee_max_kv`, `ieee_auto_recorded` | Customers served, highest distribution voltage, whether outages are logged automatically (OMS) |
| `oth_saidi_all` ... `oth_caidi_ex_med` | Same six metrics for utilities using their own storm rule |
| `oth_customers`, `oth_inactive_included`, `oth_momentary_def`, `oth_max_kv`, `oth_auto_recorded` | Same, plus the definition of a momentary interruption the utility applies |

Blanks are ".", numbers carry thousands separators. Three header rows.

### `RAW.PUDL_RELIABILITY` (24,358 rows, utility-state-year-standard, 2013 to 2024)
PUDL's cleaned long form of the same sheet across years. `standard` is `ieee_standard` or `other_standard`; both rows exist even when one is empty. `saidi_w_med` = with major event days (all events), `saidi_wo_med` = without. `data_maturity` is PUDL's flag (`final`, `provisional`).

### `RAW.PUDL_AMI` (127,720 rows, utility-state-year-customer class)
Meter counts: `advanced_metering_infrastructure` (smart meters), `automated_meter_reading` (one-way AMR), `non_amr_ami` (standard meters), `energy_served_ami_mwh`, `direct_load_control_customers`, `daily_digital_access_customers`, `home_area_network`.

### `RAW.PUDL_SALES` (198,770 rows, utility-state-year-class-service type)
`sales_mwh`, `customers`, `sales_revenue` by `customer_class` (residential, commercial, industrial, transportation, total) and `service_type` (bundled, delivery, energy).

### `RAW.NOAA_STORM_EVENTS` (831,288 rows, one per event, 2013 to 2025)
51 columns as published. Used: `state`, `year`, `event_type`, `cz_type` (`C` county, `Z` forecast zone), `cz_fips`, `cz_name`, `begin_yearmonth`, `begin_day`, `magnitude` (wind in knots for Thunderstorm Wind), `episode_id`, `event_id`.

### `RAW.NOAA_ZONE_COUNTY` (7,087 rows, zone-county)
NWS lookup: `state`, `zone`, `county_name`, `fips`. A forecast zone can span several counties.

### `RAW.EIA861_SERVICE_TERRITORY_2025` (11,803 rows, utility-state-county)
Which counties each utility serves. `utility_number`, `state`, `county`.

### `RAW.EIA930_SUBREGION` (6,077,232 rows, BA-subregion-hour, July 2018 to October 2026)
`balancing_authority`, `sub_region`, `data_date`, `hour_number` (1 to 24, hour ending), `demand_mw`, `local_time_end`, `utc_time_end`.

## STG

| View | Grain | What it does |
|---|---|---|
| `STG.RELIABILITY_2025` | utility-state-year (2025) | Unpivots the IEEE and Other blocks into one shape with a `standard` column. Types every metric as `NUMBER(12,3)`. |
| `STG.RELIABILITY_HIST` | utility-state-year (2013 to 2024) | Types PUDL, maps `ieee_standard` -> `IEEE 1366`, `other_standard` -> `Other`. Drops rows with no SAIDI at all. |
| `STG.RELIABILITY` | utility-state-year | Union of the two. Seven small utilities filed both standards in 2021: keep the IEEE row (`QUALIFY ROW_NUMBER() ... = 1`) so customers are not double counted. |
| `STG.AMI` | utility-state-year | Sums meter counts across classes, computes `ami_share`. |
| `STG.SALES` | utility-state-year-class-service type | Typed sales, customers, revenue. |
| `STG.DOMINION_VA_COUNTIES` | county | The 104 Virginia counties and cities Dominion serves, as 5-digit FIPS. EIA writes "Alexandria City", NOAA writes "City of Alexandria", both spellings are tried. |
| `STG.NOAA_VA_EVENTS` | event x county | Virginia events with a county FIPS: county events directly, zone events through the zone lookup, then a second pass on county name for zones renumbered since the lookup was built. Adds `line_risk` (wind, winter, tropical, other). |
| `STG.EIA930_DOM_HOURLY` | hour (72,864) | PJM / DOM only. `utc_ts` for the hour, `demand_mw_reported` as filed, `demand_mw` with values above 60,000 set to NULL. |

Common typed columns in `STG.RELIABILITY`:

| Column | Type | Unit | Meaning |
|---|---|---|---|
| `year` | NUMBER | | Data year |
| `utility_id`, `state`, `utility_name`, `entity_type` | | | Identity |
| `standard` | VARCHAR | | `IEEE 1366` or `Other` |
| `saidi_all`, `saidi_ex_med` | NUMBER(12,3) | minutes per customer per year | System Average Interruption Duration Index, all events / excluding major event days |
| `saifi_all`, `saifi_ex_med` | NUMBER(12,3) | interruptions per customer per year | System Average Interruption Frequency Index |
| `caidi_all`, `caidi_ex_med` | NUMBER(12,3) | minutes per interruption | Customer Average Interruption Duration Index = SAIDI / SAIFI |
| `saidi_all_minus_los` | NUMBER(12,3) | minutes | All events less loss-of-supply, IEEE filers only |
| `customers` | NUMBER | count | Customers served, the denominator of every ratio |
| `max_kv` | NUMBER(6,1) | kV | Highest distribution voltage included |
| `auto_recorded` | BOOLEAN | | Outages recorded automatically |
| `momentary_def` | VARCHAR | | Utility's definition of momentary (Other filers) |
| `inactive_included` | BOOLEAN | | Inactive accounts counted in customers |
| `source` | VARCHAR | | `EIA-861 final 2025` or `PUDL (EIA-861) 2013-2024` |

## MART

### `MART.DIM_UTILITY` (one row per utility_key)
`utility_id`, `state`, `utility_key`, `utility_name` (latest filed), `entity_type`, `peer_group`. Peer groups are assigned by ID rather than by name and are listed in `docs/04_decisions.md` D10:

| peer_group | Members |
|---|---|
| Dominion Energy Virginia | 19876-VA |
| Virginia co-op | every Virginia utility with entity type Cooperative |
| Appalachian Power (VA) | 733-VA, kept separate because its mountain terrain makes it an outlier |
| Southeast IOU peer | Duke Carolinas 5416-NC, Duke Progress 3046-NC, Georgia Power 7140-GA, Alabama Power 195-AL, Dominion SC 17539-SC |
| Mid-Atlantic IOU peer | BGE 1167-MD, Pepco 15270-MD, PECO 14940-PA, PPL 14715-PA |
| Florida IOU peer | FPL 6452-FL, Duke Energy Florida 6455-FL |
| Other | everyone else (about 950 reporting units) |

### `MART.FCT_RELIABILITY` (13,095 rows, utility_key x year, 2013 to 2025)
Everything in `STG.RELIABILITY` plus the additive numerators that make any aggregate correct:

| Column | Formula | Why |
|---|---|---|
| `storm_saidi`, `storm_saifi` | all - ex_med | Minutes and interruptions attributable to major event days |
| `cust_minutes_all`, `cust_minutes_ex_med` | SAIDI x customers | Total customer-minutes. Sum these across utilities or years, then divide by summed customers. Never average SAIDI. |
| `cust_interruptions_all`, `cust_interruptions_ex_med` | SAIFI x customers | Total customer-interruptions, same rule |

### `MART.V_TREND` (view, utility_key x year)
Adds prior-year values (`*_py`), `saidi_yoy`, `storm_share`, five-year rolling averages and `frequency_share_of_change` = ln(SAIFI ratio) / ln(SAIDI ratio), the share of a SAIDI change that came from frequency rather than duration. Guarded with `NULLIF` because Snowflake raises on `LN(0)` and some small utilities report zero.

### `MART.V_GROUP_INDEX` (view, peer_group x year)
Customer-weighted SAIFI, SAIDI, CAIDI for each peer group: `SUM(cust_interruptions_ex_med) / SUM(customers of utilities that reported it)`. This is the co-op benchmark. See `docs/03` P18 for why the denominator is matched to the numerator.

### `MART.V_VA_COOP_PANEL` (view, created in `03_analysis.sql`)
The balanced panel: Virginia co-ops with at least 10,000 customers that filed every year 2015 to 2025 (seven utilities). Used in Q3 for the robustness check; the dashboard uses the all-co-op group from `V_GROUP_INDEX`.

### `MART.STORM_INDEX` (13 rows, year)
| Column | Meaning |
|---|---|
| `storm_county_days` | Count of (county, date) pairs in Dominion's Virginia counties with at least one wind, winter or tropical event. One squall line producing 40 wind reports in one county on one day counts once. |
| `wind_days`, `winter_days`, `tropical_days` | Same, by event family |
| `severe_gust_days` | County-days with a Thunderstorm Wind gust of 60 knots or more |

### `MART.V_STORM_VS_SAIDI` (view, year)
`STORM_INDEX` joined to Dominion's row of `FCT_RELIABILITY`: adds `saidi_ex_med`, `saifi_ex_med`, `storm_saidi`. Feeds the scatter and the fit.

### `MART.SAIDI_WEATHER_ADJUSTED` (11 rows, year 2015 to 2025)
| Column | Meaning |
|---|---|
| `predicted_from_weather` | intercept + slope x storm_county_days, fitted on 2015 to 2024 (intercept 104.4, slope 0.0514 minutes per county-day) |
| `weather_adjusted_saidi` | actual - predicted + mean(2015 to 2024). What the year would have looked like with average weather |

### `MART.DOM_LOAD_ANNUAL` (9 rows, year 2018 to 2026)
`winter_peak_mw` (Dec, Jan, Feb of the calendar year), `summer_peak_mw` (Jun to Aug), `peak_mw`, `floor_mw` (lowest hour), `median_mw`, `avg_mw`, `energy_twh`, `hours_reported`, `hours_missing`. 2018 is July onward and 2026 is year to date.

### `MART.DOM_TOP50_HOURS` (96 rows)
The fifty highest-demand hours ranked two ways: `rank_end_2025` as the record stood on 31 December 2025 (the window Dominion's report describes) and `rank_today`. A row appears if it is in either top fifty.

### `MART.DOM_LOAD_PROFILE` (24 rows, hour of day)
`avg_mw_2019`, `avg_mw_2025`, `growth_pct` for each hour ending 1 to 24.

## Naming conventions

- Tables and views upper case, columns lower case snake case, as Snowflake displays them.
- `V_` prefix for views in MART, none in STG (everything in STG is a view).
- `_ex_med` = excluding major event days, `_all` = all events. Never "adjusted" for these, that word is reserved for the weather fit.
- A column that is a count of customers is always `customers`. A column that is minutes per customer is always `saidi_*`.
