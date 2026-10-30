# Names used in this project

These are just conventions to keep files and columns consistent.

## Folders

- [`data/`](../data/) — input files, lookups and exported results.
- [`sql/`](../sql/) — cleaning, calculations and checks. Files are numbered roughly in run order.
- [`powerbi/`](../powerbi/) — reporting measures and a supporting workbook.
- [`scripts/`](../scripts/) — downloads and local reproduction.
- [`docs/`](./) — explanations and source notes.

## Common terms

| You may see | Meaning |
| --- | --- |
| `RAW` | Original data loaded into Snowflake, kept as text |
| `STG` | Cleaned and consistently named data |
| `MART` | Tables prepared for calculations and Power BI |
| `saidi_ex_med` | Outage minutes per customer, excluding major event days |
| `saidi_all` | Outage minutes per customer, including all events |
| `saifi_ex_med` | Interruptions per customer, excluding major event days |
| `caidi_ex_med` | Average minutes per customer-interruption, excluding major event days |
| `utility_key` | Utility ID plus state, e.g. `19876|VA` for Dominion Virginia |
| `county_id_fips` | Standard five-digit county/city code |
| `storm_county_days` | Number of distinct county-and-date pairs with relevant NOAA events |
| `_mw`, `_twh` | Megawatts (power) and terawatt-hours (energy) |

Within SQL, `DIM_` identifies a lookup table, `FCT_` a measurement table, and `V_` a view. Tests are labelled T1–T12 so the same checks can be found in [Data quality](03_data_quality.md) and the SQL files.

The Power BI report uses plain-English chart labels, even when its underlying column names are technical.
