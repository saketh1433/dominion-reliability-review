# What the data tables mean

The main idea is simple: **start with the original files, clean them consistently, then calculate results from the cleaned records.** In Snowflake those three stages are named `RAW`, `STG` and `MART`.

## Main source tables

| Data | Typical record | Important fields |
| --- | --- | --- |
| EIA/PUDL reliability | One utility, state and year | `utility_id`, `state`, `year`, `customers`, `saidi_ex_med`, `saifi_ex_med`, `caidi_ex_med` |
| PUDL meters | One utility, year and customer class | Smart meters, older meter counts |
| PUDL sales | One utility, year, customer class and service type | Electricity sold (MWh), customers, revenue |
| NOAA storm events | One reported weather event | Date, county or forecast zone, event type, magnitude |
| EIA-930 demand | One subregion and hour | Date/time, subregion and demand in MW |

## Tables used in analysis

| Table/view | What you get from it |
| --- | --- |
| `STG.RELIABILITY` | Consistent annual reliability records covering 2013–2025 |
| `MART.FCT_RELIABILITY` | Reliability figures plus customer-minutes and customer-interruptions for correct aggregation |
| `MART.DIM_UTILITY` | Names and selected peer groups for utilities |
| `MART.V_TREND` | Previous-year values and longer-term reliability trends |
| `STG.AMI` | Smart-meter share by utility and year |
| `STG.SALES` | Sales and customers by class and service type |
| `MART.STORM_INDEX` | One row per year: storm county-days by type in Dominion Virginia's EIA service territory |
| `MART.V_STORM_VS_SAIDI` | Annual storm exposure next to annual Dominion SAIDI |
| `MART.SAIDI_WEATHER_ADJUSTED` | Exploratory regression predictions and adjusted figures |
| `MART.DOM_LOAD_ANNUAL` | Yearly highest, lowest and average hourly electricity demand |
| `MART.DOM_LOAD_PROFILE` | Average demand by hour of day for 2019 versus 2025 |

For Dominion's Virginia reliability records, `utility_id = 19876` and `state = 'VA'`. Combining them as `19876|VA` avoids confusing one utility's records across states.

## Units to watch

- **SAIDI:** outage minutes **per customer**.
- **SAIFI:** sustained interruptions **per customer**.
- **CAIDI:** minutes **per customer-interruption**.
- **MW:** demand at a point in time. **MWh/TWh:** electricity consumed over a period.

A customer-interruption is **not** the same as one distinct incident on the grid: one incident can interrupt many customers.

For actual column definitions and SQL expressions, see [`sql/01_raw_staging.sql`](../sql/01_raw_staging.sql), [`sql/02_mart.sql`](../sql/02_mart.sql), [`sql/05_noaa_storms.sql`](../sql/05_noaa_storms.sql) and [`sql/06_eia930_demand.sql`](../sql/06_eia930_demand.sql).
