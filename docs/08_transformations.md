# 08. Transformations

The processing chain from source file to report figure, with worked examples on actual rows from the files in `data/` and the sources in `docs/01_sources.md`.

## Processing chain

| Step | Layer | Operation | Code |
|---|---|---|---|
| 1 Load | RAW | The file is copied into a table with every column as text. No values are changed or dropped. | `01`, `05`, `06`: `COPY INTO` |
| 2 Type | STG | Text is converted to numbers, dates and booleans. Thousands separators are removed. A value that fails conversion becomes NULL and T6 reports it. | `01`: `TRY_TO_NUMBER(REPLACE(x, ',', ''))` |
| 3 Reshape | STG | EIA 2025: the two side-by-side column blocks become one column set with a `standard` label. NOAA: zone events are mapped to counties. EIA-930: rows are filtered to the DOM zone. | `01`: `UNION ALL`; `05`: zone join; `06`: `WHERE sub_region = 'DOM'` |
| 4 De-duplicate | STG | One row per utility, state and year. Where a utility filed under both standards, the IEEE row is kept. | `01`: `QUALIFY ROW_NUMBER() ... = 1` |
| 5 Derive | MART | Customer-minutes and customer-interruptions are stored for aggregation. Peer groups are assigned by ID. | `02`: `FCT_RELIABILITY`, `DIM_UTILITY` |
| 6 Index and fit | MART | Storm county-days per year. Weather fit. Hourly peaks, floor and top-50 ranking. | `05`, `06`, `07` |
| 7 Test | MART | Twelve queries with stated expected results. | `04`, `05`, `06` |
| 8 Present | Power BI | Measures sum numerators and divide once. | `powerbi/measures.dax` |

## Worked example 1: three-year SAIDI, 133.0

**Step 1, the source row.** `data/input/Reliability_2025_States.csv`, utility 19876, Virginia. The file has three header rows and uses "." for blanks. Dominion files under the Other standard; the IEEE block is blank.

| Column in the file | Value as text |
|---|---|
| Utility Number | `19876` |
| Utility Name | `Virginia Electric & Power Co` (the legal name filed with EIA) |
| Ownership | `Investor Owned` |
| IEEE SAIDI, all events | `.` (blank) |
| Other SAIDI, all events | `306.700` |
| Other SAIDI, without major event days | `144.400` |
| Other SAIFI, without major event days | `1.320` |
| Other CAIDI, without major event days | `109.394` |
| Other customers | `2,675,735` |
| Highest distribution voltage | `46.0` |
| Outages recorded automatically | `Y` |

**Step 2, load and type.** `COPY INTO` with file format `FF_EIA_CSV` (`SKIP_HEADER = 3`, `NULL_IF = ('.')`) loads the row as text. The staging view converts `2,675,735` to 2675735 with `TRY_TO_NUMBER(REPLACE(oth_customers, ',', ''))` and `144.400` to `NUMBER(12,3)`.

**Step 3, reshape.** `STG.RELIABILITY_2025` is two `SELECT` statements joined by `UNION ALL`: one reads the IEEE block with `standard = 'IEEE 1366'`, the other reads the Other block with `standard = 'Other'`. Each keeps rows where that block contains a SAIDI. Dominion appears once, from the second `SELECT`.

**Step 4, union with history and de-duplicate.** PUDL supplies 2013 to 2024 in a long format with a row for each standard per utility, including empty rows. `STG.RELIABILITY_HIST` keeps rows with a value; for Dominion this is one row per year, all `Other`. `STG.RELIABILITY` unions history and 2025 and keeps one row per utility, state and year. Seven utilities filed under both standards in 2021 (including Pennyrile Rural Electric, Upper Cumberland EMC and several Tennessee municipals); the IEEE row is kept for each. Dominion has no duplicate.

**Step 5, derive.** `FCT_RELIABILITY` stores the products used for aggregation:

| Column | 2023 | 2024 | 2025 |
|---|---|---|---|
| `saidi_ex_med` | 123.322 | 131.300 | 144.400 |
| `customers` | 2,612,104 | 2,635,267 | 2,675,735 |
| `cust_minutes_ex_med` = saidi x customers | 322,129,889 | 346,010,557 | 386,376,134 |
| `storm_saidi` = all - ex_med | 66.876 | 40.800 | 162.300 |

**Step 8, the measure.** `SAIDI 3yr ending 2025` is `AVERAGEX(VALUES(YEAR), [SAIDI ex MED])` filtered to 2023 to 2025, where `[SAIDI ex MED]` is `DIVIDE(SUM(CUST_MINUTES_EX_MED), SUM(CUSTOMERS))`. For a single utility this is (123.3 + 131.3 + 144.4) / 3 = **133.0**. Annual report, page 10: 133. The same measure for 2022 to 2024 is (136.0 + 123.3 + 131.3) / 3 = **130.2**. Annual report: 130.

**Verification.** Open the CSV and read 144.400 from the row for 19876 VA. Open `data/input/pudl_reliability_2013_2024.csv`, filter `utility_id_eia = 19876` and `state = VA` and read `saidi_wo_major_event_days_minutes` for 2023 and 2024. Average the three values. `python scripts/run_local_duckdb.py` performs the same steps and prints Q1.

## Worked example 2: customer-weighted aggregation

The nine Virginia cooperatives that reported SAIFI ex-MED for 2025:

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

Mean of the nine ratios: **2.439**. Each utility carries equal weight regardless of size.

Customer-weighted: sum of (SAIFI x customers) = 1,249,316 interruptions, divided by 662,237 customers = **1.887**. All group figures in the report use the customer-weighted form, which is why `FCT_RELIABILITY` stores the products.

A tenth co-op, Prince George Electric, reported SAIDI but no SAIFI for 2025. A denominator summing all ten utilities' customers would include its 13,341 and give 1.849. `V_GROUP_INDEX` sums only the customers of utilities that reported the numerator, giving 1.887. The report's co-op index (each year relative to 2015) is 137.4 under either denominator because Prince George is absent in every year. Recorded as P18 in `docs/03_data_quality.md`.

## Worked example 3: storm events to a county-day

**Source rows.** On 18 July 2025 NOAA recorded five Thunderstorm Wind events in Chesterfield County, all in episode 205761, `CZ_TYPE = C`, `CZ_FIPS = 41`:

| EVENT_ID | BEGIN_DATE_TIME | EVENT_TYPE | MAGNITUDE | BEGIN_LOCATION |
|---|---|---|---|---|
| 1284464 | 18-JUL-25 18:45 | Thunderstorm Wind | 50 kt | KINGSLAND |
| 1284465 | 18-JUL-25 18:45 | Thunderstorm Wind | 50 kt | CHESTER |
| 1284466 | 18-JUL-25 18:45 | Thunderstorm Wind | 50 kt | CHESTERFIELD |
| 1284467 | 18-JUL-25 18:47 | Thunderstorm Wind | 50 kt | CHESTERFIELD |
| 1284472 | 18-JUL-25 18:54 | Thunderstorm Wind | 50 kt | CHESTER |

**Step 3, county code.** For a county event the code is the state FIPS followed by the county FIPS padded to three digits: `'51' || LPAD('41', 3, '0')` = `51041`. `Thunderstorm Wind` maps to `line_risk = 'wind'`.

**Step 6, county-day.** `STORM_INDEX` groups by year, county and date. The five rows become one row: county 51041, 18 July 2025, wind = 1. Across the 104 Dominion counties in Virginia, 2025 has 796 county-days with a wind, winter or tropical event. 2024 had 465.

**Zone events.** The winter storm of 5 January 2025 was filed against forecast zones: `CZ_TYPE = Z`, `CZ_FIPS` 513 (Western Chesterfield), 514 (Eastern Chesterfield), 515 (Western Henrico), 516 (Eastern Henrico). The NWS zone-county correlation file maps each zone to its counties: zone 513 to Chesterfield (51041); zone 515 to Henrico (51087) and the City of Richmond (51760). Each mapped county receives a county-day. The correlation file has gaps (zone 514 maps only to Colonial Heights), which is one reason the index is treated as a measure of exposure rather than damage.

**Dominion's counties.** EIA's 2025 Service Territory file lists 104 counties and cities for utility 19876 in Virginia. EIA writes "Alexandria City" and NOAA writes "City of Alexandria", so both spellings are tried. T7 confirms all 104 resolve to a FIPS code.

## Worked example 4: hourly demand to the top-50 count

**Source row.** `EIA930_SUBREGION_2025_Jan_Jun.csv`, line 171,407:

```
PJM,01/23/2025,8,DOM,24957,01/23/2025 8:00:00 AM,01/23/2025 1:00:00 PM
```

Balancing authority PJM, subregion DOM, hour ending 08:00 local on 23 January 2025, 24,957 MW. This is the highest hour in the record to the end of 2025.

**Step 3, filter and type.** `STG.EIA930_DOM_HOURLY` keeps rows where `balancing_authority = 'PJM' AND sub_region = 'DOM'` (72,864 of 6,077,232), parses both timestamps and keys on UTC so that clock-change days do not produce duplicates.

**Anomalous rows.** `EIA930_SUBREGION_2021_Jul_Dec.csv`, lines 216,193 and 216,213:

```
PJM,10/18/2021,23,DOM,1526640000,...
PJM,10/18/2021,24,DOM,1038460000,...
```

The staging view retains the reported value in `demand_mw_reported` and sets `demand_mw` to NULL above 60,000 MW. T10 lists these two rows.

**Step 6, rank.** `DOM_TOP50_HOURS` ranks every hour by demand, once over the full record and once over hours to 31 December 2025. Top fifty by year at the second reference date:

| Year | Hours in the top 50 |
|---|---|
| 2024 | 3 |
| 2025 | 47 |

**Annual floor and peak.** Lowest hour of 2019: 7,167 MW, 04:00 on 28 April. Lowest hour of 2025: 10,903 MW, 05:00 on 27 April. Change +52%. Highest hour of 2019: 19,803 MW, 08:00 on 31 January. Highest hour of 2025: 24,957 MW as above. Change +26%. `DOM_LOAD_PROFILE` makes the same comparison for each hour of the day: 04:00 +41%, 16:00 +27%.

## Worked example 5: weather adjustment

Fit on 2015 to 2024: SAIDI ex-MED = 104.4 + 0.0514 x storm county-days. Mean SAIDI ex-MED over the ten years: 134.0.

| 2025 | Value |
|---|---|
| Storm county-days | 796 |
| Predicted from weather | 104.4 + 0.0514 x 796 = **145.3** |
| Actual | 144.4 |
| Weather-adjusted | 144.4 - 145.3 + 134.0 = **133.1** |

For 2019 (851 county-days, actual 149.9) the same calculation gives 135.8.

## Cleaning rules

| Rule | Applies to | Reason | Verification |
|---|---|---|---|
| Skip three header rows and treat "." as NULL | EIA-861 2025 | Format of the EIA export | Row count 977 |
| Remove thousands separators before typing | Numeric columns from EIA | Values are exported as formatted text | T6 returns no rows |
| All RAW columns are text | All sources | Typing failures are visible in a view rather than dropped at load | Row counts match the files |
| Unpivot the IEEE and Other blocks | EIA-861 2025 | One column set with the standard as a label | Query B in `00`: 751 IEEE, 212 Other, 1 both, 13 neither |
| Drop PUDL rows with no SAIDI under either standard | PUDL 2013 to 2024 | PUDL includes empty rows for both standards | Query D in `00` |
| One row per utility, state and year, IEEE row kept | Union of history and 2025 | Customers counted once | T1 returns no rows |
| Store customer-minutes and customer-interruptions | `FCT_RELIABILITY` | Customer-weighted aggregation | Query G in `00`: 2.439 vs 1.887 |
| Group denominators include only utilities that reported the numerator | `V_GROUP_INDEX` | A utility with customers but no SAIFI must not dilute the group figure | P18 |
| County code from FIPS, zones mapped through the NWS correlation file with a second pass on name | NOAA | Events must resolve to counties to match the service territory | T7 and T9 return no rows |
| Count county-days, not events | `STORM_INDEX` | Multiple reports per storm | Grouping in `STORM_INDEX` |
| Filter to PJM / DOM, key on UTC, cap at 60,000 MW | EIA-930 | Zone of interest, no clock-change duplicates, two anomalous rows | T10 returns 2, T11 and T12 return none |
| Fit on 2015 to 2024, predict 2025 out of sample | `SAIDI_WEATHER_ADJUSTED` | The test year is excluded from the fit | Decision D6 |

## Verifying a report figure

1. Locate the figure in `docs/05_metrics_and_measures.md`, which names the table and the calculation.
2. Read the table definition in `docs/02_data_dictionary.md` to identify the source columns.
3. Open the source file in `data/input/`, or download it from the link in `docs/01_sources.md` and locate the rows.
4. Reproduce the calculation as above, or run `python scripts/run_local_duckdb.py` for the reliability mart.
5. If the figure does not match, the relevant test in `docs/03_data_quality.md` indicates where to look.
