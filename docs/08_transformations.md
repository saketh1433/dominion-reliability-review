# 08. From the raw file to the number on the dashboard

Every figure in the report is the end of a short chain: a cell in a public file, a load, a typing step, a reshape, a calculation, a test, a measure. This document walks the chain with real values so anyone can repeat it by hand with the files in `data/` and the links in `docs/01_sources.md`.

## The chain at a glance

| Step | Layer | What happens | Where in the code |
|---|---|---|---|
| 1 Load | RAW | The file is copied into a table with every column as text. Nothing is changed, nothing is dropped. | `01`, `05`, `06`: `COPY INTO` |
| 2 Type | STG | Text becomes numbers, dates and booleans. Thousands separators are stripped. A value that cannot be typed becomes NULL and test T6 reports it. | `01`: `TRY_TO_NUMBER(REPLACE(x, ',', ''))` |
| 3 Reshape | STG | Two side-by-side blocks become one column set with a `standard` label (EIA 2025). Zone events are spread to counties (NOAA). Only the DOM zone is kept (EIA-930). | `01`: `UNION ALL`, `05`: zone join, `06`: `WHERE sub_region = 'DOM'` |
| 4 De-duplicate | STG | One row per utility, state and year. Where a utility filed both standards, the IEEE row wins. | `01`: `QUALIFY ROW_NUMBER() ... = 1` |
| 5 Derive | MART | Customer-minutes and customer-interruptions are stored so any aggregate can be recomputed correctly. Peer groups are attached by ID. | `02`: `FCT_RELIABILITY`, `DIM_UTILITY` |
| 6 Index and fit | MART | Storm county-days per year. Weather fit. Hourly peaks, floor, top-50 ranking. | `05`, `06`, `07` |
| 7 Test | MART | Twelve queries that return zero rows when the data is sound. | `04`, `05`, `06` |
| 8 Present | Power BI | Measures sum numerators and divide once. Titles state the finding. | `powerbi/measures.dax` |

## Worked example 1: Dominion's headline number, 133.0

**Step 1, the raw cell.** `data/input/Reliability_2025_States.csv`, the row for utility 19876 in Virginia. The file has three header rows and uses "." for blank. Dominion files under the "Other" standard, so the IEEE block is blank and the Other block holds the values:

| Column in the file | Value as text |
|---|---|
| Utility Number | `19876` |
| Utility Name | `Virginia Electric & Power Co` (Dominion's legal name on the form, which is why a search for "Dominion" finds nothing in Virginia) |
| Ownership | `Investor Owned` |
| IEEE SAIDI, all events | `.` (blank) |
| Other SAIDI, all events | `306.700` |
| Other SAIDI, without major event days | `144.400` |
| Other SAIFI, without major event days | `1.320` |
| Other CAIDI, without major event days | `109.394` |
| Other customers | `2,675,735` |
| Highest distribution voltage | `46.0` |
| Outages recorded automatically | `Y` |

**Step 2, load and type.** `COPY INTO` with file format `FF_EIA_CSV` (`SKIP_HEADER = 3`, `NULL_IF = ('.')`) lands the row as text. The staging view turns `2,675,735` into 2675735 by `TRY_TO_NUMBER(REPLACE(oth_customers, ',', ''))` and `144.400` into 144.400 as `NUMBER(12,3)`.

**Step 3, reshape.** The view `STG.RELIABILITY_2025` is two `SELECT`s joined by `UNION ALL`: one reads the IEEE block and labels it `IEEE 1366`, the other reads the Other block and labels it `Other`. Each keeps only rows where that block has a SAIDI. Dominion appears once, from the second `SELECT`, with `standard = 'Other'`.

**Step 4, union with history and de-duplicate.** PUDL supplies 2013 to 2024 in a long format where every utility has a row for each standard, blank or not. `STG.RELIABILITY_HIST` keeps the rows with a value. For Dominion that is one row a year, all `Other`. `STG.RELIABILITY` unions history and 2025 and keeps one row per utility, state and year. Seven small utilities filed under both standards in 2021 (Pennyrile Rural Electric, Upper Cumberland EMC and five Tennessee municipals among them) and the rule keeps their IEEE row so their customers are counted once. Dominion has no duplicate and passes through unchanged.

**Step 5, derive.** `FCT_RELIABILITY` multiplies each ratio back into a total so it can be aggregated:

| Column | 2023 | 2024 | 2025 |
|---|---|---|---|
| `saidi_ex_med` | 123.322 | 131.300 | 144.400 |
| `customers` | 2,612,104 | 2,635,267 | 2,675,735 |
| `cust_minutes_ex_med` = saidi x customers | 322,129,889 | 346,010,557 | 386,376,134 |
| `storm_saidi` = all - ex_med | 66.876 | 40.800 | 162.300 |

**Step 8, the measure.** `SAIDI 3yr ending 2025` is `AVERAGEX(VALUES(YEAR), [SAIDI ex MED])` filtered to 2023 to 2025, where `[SAIDI ex MED]` is `DIVIDE(SUM(CUST_MINUTES_EX_MED), SUM(CUSTOMERS))`. For one utility that is (123.3 + 131.3 + 144.4) / 3 = **133.0**. The annual report, page 10, says 133. The same measure for 2022 to 2024 gives (136.0 + 123.3 + 131.3) / 3 = **130.2**. The report says 130.

**How to check it yourself.** Open the CSV, find row 19876 VA, read 144.400. Open `data/input/pudl_reliability_2013_2024.csv`, filter `utility_id_eia = 19876`, `state = VA`, read `saidi_wo_major_event_days_minutes` for 2023 and 2024. Average the three. Or run `python scripts/run_local_duckdb.py`, which does all of it and prints Q1.

## Worked example 2: why ratios are never averaged

The nine Virginia cooperatives that reported a SAIFI ex-MED for 2025:

| Co-op | SAIFI ex-MED | Customers |
|---|---|---|
| A & N Electric | 2.279 | 37,914 |
| Central Virginia Electric | 3.470 | 39,308 |
| Mecklenburg Electric | 1.956 | 31,280 |
| Northern Neck Electric | 2.168 | 21,079 |
| Northern Virginia Electric (NOVEC) | 0.583 | 179,398 |
| Powell Valley Electric | 4.267 | 8,406 |
| Rappahannock Electric | 2.020 | 184,314 |
| Shenandoah Valley Electric | 2.340 | 101,226 |
| Southside Electric | 2.866 | 59,312 |

Average of the nine ratios: **2.439**. Powell Valley's 8,406 customers count exactly as much as Rappahannock's 184,314.

Customer-weighted: sum of (SAIFI x customers) = 1,249,316 interruptions, divided by 662,237 customers = **1.887**. That is what a typical co-op customer experienced. The two numbers differ by 29% and only the second is right. Every group figure in the report is built the second way, which is why `FCT_RELIABILITY` stores the multiplied-out numerators.

One subtlety found while writing this page: a tenth co-op, Prince George Electric, reported SAIDI but no SAIFI for 2025. A denominator that sums all customers would include its 13,341 and give 1.849. `V_GROUP_INDEX` now sums only the customers of utilities that reported the numerator, which gives 1.887. The dashboard shows the index (each year divided by 2015) and the index is the same to one decimal either way (137.4), because Prince George is missing in every year. Recorded as P18 in `docs/03_data_quality.md`.

## Worked example 3: a storm, from NOAA row to a county-day

**The raw rows.** On 18 July 2025 a line of thunderstorms crossed Chesterfield County. NOAA's 2025 file has five rows for it, all in episode 205761, all `CZ_TYPE = C` (county), `CZ_FIPS = 41`:

| EVENT_ID | BEGIN_DATE_TIME | EVENT_TYPE | MAGNITUDE | BEGIN_LOCATION |
|---|---|---|---|---|
| 1284464 | 18-JUL-25 18:45 | Thunderstorm Wind | 50 kt | KINGSLAND |
| 1284465 | 18-JUL-25 18:45 | Thunderstorm Wind | 50 kt | CHESTER |
| 1284466 | 18-JUL-25 18:45 | Thunderstorm Wind | 50 kt | CHESTERFIELD |
| 1284467 | 18-JUL-25 18:47 | Thunderstorm Wind | 50 kt | CHESTERFIELD |
| 1284472 | 18-JUL-25 18:54 | Thunderstorm Wind | 50 kt | CHESTER |

**Step 3, give every row a county code.** For a county event the code is the state FIPS plus the county FIPS padded to three digits: `'51' || LPAD('41', 3, '0')` = `51041`. `Thunderstorm Wind` maps to `line_risk = 'wind'`.

**Step 6, collapse to a county-day.** `STORM_INDEX` groups by year, county and date. The five rows become one row: county 51041, 18 July 2025, wind = 1. One squall line reported five times counts once. Across all 104 of Dominion's Virginia counties, 2025 has 796 such county-days (wind, winter or tropical). 2024 had 465.

**Zone events work through a lookup.** The winter storm of 5 January 2025 was filed against forecast zones, not counties: `CZ_TYPE = Z`, `CZ_FIPS = 513` "WESTERN CHESTERFIELD", 514 "EASTERN CHESTERFIELD", 515 "WESTERN HENRICO", 516 "EASTERN HENRICO". NOAA's zone-county correlation file turns each zone into the counties it covers: zone 513 is Chesterfield (51041), zone 515 is Henrico (51087) and the City of Richmond (51760) and so on. Each county the lookup lists gets a county-day. The lookup is NOAA's own and is imperfect (zone 514 lists only Colonial Heights), which is one reason the index is a measure of exposure, not of damage.

**Which counties are Dominion's.** EIA's 2025 Service Territory file lists the counties each utility serves. For utility 19876 in Virginia that is 104 entries. EIA writes "Alexandria City", NOAA writes "City of Alexandria", so both spellings are tried. Test T7 confirms every one of the 104 found a FIPS code.

## Worked example 4: an hour of demand, from EIA-930 to "47 of 50"

**The raw row.** `EIA930_SUBREGION_2025_Jan_Jun.csv`, line 171,407:

```
PJM,01/23/2025,8,DOM,24957,01/23/2025 8:00:00 AM,01/23/2025 1:00:00 PM
```

Balancing authority PJM, Dominion's DOM zone, hour ending 8am local on 23 January 2025, 24,957 MW. That is the highest hour in the record to the end of 2025, during the January cold snap.

**Step 3, keep the zone, type the time.** `STG.EIA930_DOM_HOURLY` keeps rows where `balancing_authority = 'PJM' AND sub_region = 'DOM'` (72,864 of 6,077,232), parses both timestamps and uses the UTC one as the key so the clock-change days do not create duplicates.

**The two impossible rows.** `EIA930_SUBREGION_2021_Jul_Dec.csv` lines 216,193 and 216,213:

```
PJM,10/18/2021,23,DOM,1526640000,...
PJM,10/18/2021,24,DOM,1038460000,...
```

1.5 billion MW for a zone that peaks near 25,000. The view keeps the reported value in `demand_mw_reported` and sets `demand_mw` to NULL above 60,000. Test T10 lists exactly these two rows.

**Step 6, rank.** `DOM_TOP50_HOURS` numbers every hour from highest to lowest, once over the whole record and once over hours up to 31 December 2025. Count the top fifty by year:

| Year | Hours in the top 50, as of end 2025 |
|---|---|
| 2024 | 3 |
| 2025 | 47 |

**The same data, the other way round.** The lowest hour of 2019 was 7,167 MW at 4am on 28 April. The lowest hour of 2025 was 10,903 MW at 5am on 27 April. Up 52%. The highest hour of 2019 was 19,803 MW at 8am on 31 January; 2025's was the 24,957 above. Up 26%. `DOM_LOAD_PROFILE` does the same comparison for each hour of the day: 4am is up 41%, 4pm is up 27%.

## Worked example 5: the weather adjustment, by hand

Fit, on 2015 to 2024: SAIDI ex-MED = 104.4 + 0.0514 x storm county-days. Mean SAIDI ex-MED over those ten years: 134.0.

| 2025 | Value |
|---|---|
| Storm county-days | 796 |
| Predicted from weather | 104.4 + 0.0514 x 796 = **145.3** |
| Actual | 144.4 |
| Weather-adjusted | 144.4 - 145.3 + 134.0 = **133.1** |

The same arithmetic for 2019 (851 county-days, actual 149.9) gives 135.8. Weather-adjusted, 2019 and 2025 are three minutes apart.

## The cleaning rules, listed

| Rule | Applied to | Why | Check |
|---|---|---|---|
| Skip three header rows, treat "." as NULL | EIA-861 2025 | How EIA exports the sheet | Row count 977 |
| Strip thousands separators before typing | Every numeric column from EIA | "2,675,735" is text until the comma goes | T6 returns no rows |
| Every RAW column is text | All sources | A typing failure should show up in a view, not silently drop a row at load | Row counts match the files |
| Unpivot the IEEE and Other blocks | EIA-861 2025 | One column set, with the standard as a label | Query B in `00`: 751 IEEE, 212 Other, 1 both, 13 neither |
| Drop PUDL rows with no SAIDI under either name | PUDL 2013 to 2024 | PUDL writes both standards for every utility | Query D in `00` |
| One row per utility, state and year, IEEE wins | Union of history and 2025 | Customers must not be counted twice | T1 returns no rows |
| Store customer-minutes and customer-interruptions | `FCT_RELIABILITY` | Aggregates must be customer-weighted | Query G in `00`: 2.439 vs 1.887 |
| Group denominators count only utilities that reported the numerator | `V_GROUP_INDEX` | A utility with customers but no SAIFI must not dilute the group | P18 |
| County code from FIPS, zones through NOAA's lookup, second pass on name | NOAA | Events must land in counties to be matched to a utility | T7 and T9 return no rows |
| Count county-days, not events | `STORM_INDEX` | One storm, many reports | By construction |
| Keep only PJM / DOM, key on UTC, cap at 60,000 MW | EIA-930 | The zone of interest, no clock-change duplicates, two impossible rows | T10 returns 2, T11 and T12 return none |
| Fit on 2015 to 2024, predict 2025 out of sample | `SAIDI_WEATHER_ADJUSTED` | The test year must not shape the line it is tested against | Decision D6 |

## How to verify any dashboard number in five minutes

1. Find it in `docs/05_metrics_and_measures.md`, which names the table and the calculation.
2. Open the table definition in `docs/02_data_dictionary.md` to see which raw columns feed it.
3. Open the raw file from `data/input/` or re-download it from the link in `docs/01_sources.md` and find the rows.
4. Run the calculation by hand as above, or run `python scripts/run_local_duckdb.py` for the reliability mart.
5. If the number does not match, the test in `docs/03_data_quality.md` that covers it says what to look at.
