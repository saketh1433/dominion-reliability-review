# Where the data came from

This review uses **public information only**, not Dominion's internal outage or equipment records.

| Source | Years used | Why it was needed |
| --- | --- | --- |
| [EIA-861](https://www.eia.gov/electricity/data/eia861/) | 2025 | Dominion's latest reported outage minutes, interruption frequency, customers and service area |
| [PUDL (standardized EIA-861)](https://docs.catalyst.coop/pudl/en/stable/data_access.html) | Reliability: 2013–2024; meters and sales: 2013–2025 | Historical reliability trends, meter counts and sales by customer class |
| [NOAA Storm Events](https://www.ncei.noaa.gov/pub/data/swdi/stormevents/csvfiles/) | 2013–2025 | Dates, locations and types of recorded storms |
| [NWS zone-to-county lookup](https://www.weather.gov/gis/ZoneCounty) | Reference lookup | Convert weather forecast zones into counties |
| EIA-861 service-territory file | 2025 | Identify the 104 Virginia counties and independent cities in Dominion's reported service territory |
| [EIA-930](https://www.eia.gov/electricity/gridmonitor/) | July 2018–October 2026 | Hourly demand in PJM's DOM subregion |
| [Dominion annual report](https://investors.dominionenergy.com/) and investor presentations | Published company reports | Check the reported headline numbers and add business context |

## Where the files are

- [`data/input/`](../data/input/) holds the smaller EIA and PUDL files.
- [`data/reference/`](../data/reference/) holds the geographic lookups and selected investor-presentation figures.
- [`data/output/`](../data/output/) holds annual storm and demand summaries.
- Large raw NOAA and EIA-930 downloads are **not stored in GitHub**. The scripts in [`scripts/`](../scripts/) can fetch them into local `data/raw/`.

## Two distinctions worth remembering

**EIA-861 is annual utility reporting. EIA-930 is hourly regional demand data.** They answer different questions.

**The PJM DOM subregion is not identical to Dominion's Virginia retail territory.** Use the first for broad demand trends; use EIA-861 utility-state records for reported Virginia reliability.

The 2025 EIA-861 release used here was the final October 2026 release. NOAA may revise past storm records, and 2026 demand data is incomplete. The source files and dates should be checked before refreshing the results.
