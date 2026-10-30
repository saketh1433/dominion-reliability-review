# What I checked before trusting the numbers

Public datasets aren't always ready to compare. I checked their formats, missing values and inconsistent records before calculating results.

| Problem | What I did |
| --- | --- |
| EIA's 2025 file stored some numbers as text, including `"2,675,735"` | Removed commas and converted the values to numbers |
| EIA and PUDL used different reporting layouts | Standardized the columns and appended the historical years to 2025 |
| Some utilities had duplicate records for the same year under two reporting methods | Kept one record per utility, state and year |
| NOAA recorded several events in one county on the same day | Counted one **county-day**, not every report |
| NOAA sometimes used forecast zones instead of counties | Used an NWS mapping to assign events to counties |
| Two EIA-930 demand records were above one **billion MW** | Kept the original values for review but excluded them from calculations |
| EIA-930 local clock times can repeat during daylight-saving changes | Used UTC timestamps to distinguish hours |

## Checks in the SQL

The code includes **12 checks (T1–T12)** in [`sql/04_tests.sql`](../sql/04_tests.sql), [`sql/05_noaa_storms.sql`](../sql/05_noaa_storms.sql) and [`sql/06_eia930_demand.sql`](../sql/06_eia930_demand.sql). They check duplicates, consistency of SAIDI/SAIFI/CAIDI, source values, county matching, hourly records and unusually high demand.

Most checks should return **zero unexpected records**. Some intentionally flag known source issues: four EIA reliability anomalies and two unrealistic EIA-930 demand readings. A flag is a reason to investigate, not automatically a reason to delete a record.

## Important limitations

- EIA figures are reported by utilities. My checks verify consistency; they **cannot independently verify every outage**.
- Dominion uses its own major-event-day exclusion rule, while many peers use IEEE 1366. Comparisons are therefore approximate.
- Dominion's outage-recording practices changed in 2015; its reported distribution-voltage scope changed in 2020. Trend charts mark those breaks.
- Without feeder-level records, public data cannot identify the equipment or maintenance conditions behind an outage.

**Why this matters:** An accurate calculation on inconsistent data can still produce a misleading business conclusion.
