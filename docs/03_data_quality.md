# 03. Data quality

Profiling findings on the raw files, the handling of each in SQL and the tests T1 to T12 that run after each load.

## Profiling findings

Found by profiling RAW (`sql/00_look_first.sql`) or by a test on the first load. Each is handled in SQL so that it applies to every subsequent load.

| # | Source | Finding | Handling | Location |
|---|---|---|---|---|
| P1 | EIA-861 2025 | Three header rows; blanks written as "." | File format `SKIP_HEADER = 3`, `NULL_IF = ('.')` | `01`, `FF_EIA_CSV` |
| P2 | EIA-861 2025 | Numbers carry thousands separators ("2,675,735") | `TRY_TO_NUMBER(REPLACE(x, ',', ''))` on every numeric column | `01`, `STG.RELIABILITY_2025` |
| P3 | EIA-861 2025 | IEEE 1366 and Other-standard metrics in two side-by-side column blocks; each utility fills one | Unpivot with `UNION ALL`; `standard` column records the block | `01` |
| P4 | EIA-861 2025 | Eight utilities report ex-MED values without all-events values | Retained: filter is `saidi_all IS NOT NULL OR saidi_ex_med IS NOT NULL` | `01` |
| P5 | PUDL | A row exists for both standards for every utility, including empty rows | Rows with no SAIDI under either standard are dropped | `01`, `STG.RELIABILITY_HIST` |
| P6 | PUDL and EIA union | Seven utilities filed under both standards in 2021 | De-duplicated with `QUALIFY ROW_NUMBER() ... = 1`; the IEEE row is kept so customers are counted once | `01`, `STG.RELIABILITY` |
| P7 | EIA-861 | Counting rule changes in 2015 (automated outage recording) and 2020 (46 kV lines included) shift Dominion's series | Not adjusted in data. Marked on trend charts. 2013 and 2014 excluded from the weather fit | charts, `07` |
| P8 | EIA-861 | Four utility-years where all-events SAIDI is lower than ex-MED SAIDI | Retained in `FCT_RELIABILITY` so the load matches EIA. The utilities concerned are in the `Other` peer group and outside the peer sets. T3 reports the count on every run | `04`, T3 |
| P9 | NOAA | Zone events (`cz_type = 'Z'`) reference a forecast zone, not a county | Mapped to counties through the NWS zone-county correlation file | `05`, `STG.NOAA_VA_EVENTS` |
| P10 | NOAA | 140 zone events reference zones renumbered after the lookup was published | Second pass matches `UPPER(cz_name)` to the county name. T9 confirms none remain unmapped | `05`, T9 |
| P11 | NOAA vs EIA | County name spellings differ between sources ("Alexandria City" vs "City of Alexandria"); James City and Charles City are county names | Both spellings are tried; `MIN(fips)` per EIA county. T7 confirms all 104 counties resolve | `05`, T7 |
| P12 | NOAA | One storm can produce many event rows in one county on one day | The index counts county-days, not events | `05`, `STORM_INDEX` |
| P13 | EIA-930 | Two hours on 18 October 2021 report 1.5 billion and 1.0 billion MW for a zone that peaks near 25,000 MW | Values above 60,000 MW set to NULL in staging; the reported value is retained in `demand_mw_reported`. T10 lists the rows | `06`, T10 |
| P14 | EIA-930 | 2,020 hours have no demand value (1,729 in 2018) | Left NULL. `hours_missing` recorded per year in `DOM_LOAD_ANNUAL`. T12 checks each full year has at least 8,700 reported hours | `06`, T12 |
| P15 | EIA-930 | Local time has 23-hour and 25-hour days at clock changes | Hourly logic keyed on `utc_ts`. T11 confirms no duplicate hour | `06`, T11 |
| P16 | EIA-930 | `EIA930_SUBREGION_2018_Jan_Jun.csv` is served as an HTML error page (subregion reporting starts July 2018) | Not loaded. The download script removes it | `scripts/download_eia930.sh` |
| P17 | EIA-861 vs annual report | EIA customers for Dominion VA are 2,675,735 and the annual report states 2,809k | Not an error. The report figure includes North Carolina. Stated on the scorecard | report |
| P18 | EIA-861 | Prince George Electric filed SAIDI but no SAIFI for 2025. A group denominator summing all members' customers would include its 13,341 customers and understate the co-op SAIFI (1.849 instead of 1.887) | `V_GROUP_INDEX` denominators sum only the customers of utilities that reported the numerator. The co-op index (each year relative to 2015) is unchanged to one decimal (137.4) | `02`, `V_GROUP_INDEX` |
| P19 | EIA-930 vs company reports | Dominion's earnings decks report DOM zone peaks of 22,189 MW (24 Dec 2022), 21,993 MW (28 Jul 2023) and 23,127 MW (16 Jul 2024). EIA-930 hourly maxima on the same days are 22,415, 22,050 and 23,220 MW, within 1.1% | Confirms EIA-930 as a proxy for the zone load. The difference is hourly-integrated EIA data against PJM's reported peak | `DOM_LOAD_ANNUAL`, `data/reference/dominion_ir_series.csv` |

## Tests

Run after every load. A result other than the expected one stops the refresh until explained.

| Test | File | Check | Expected | Result, this build | If it fails |
|---|---|---|---|---|---|
| T1 | 04 | No duplicate utility-state-year in `FCT_RELIABILITY` | 0 rows | 0 | De-duplication in `STG.RELIABILITY` failed, or a new file overlaps years already loaded |
| T2 | 04 | SAIDI = SAIFI x CAIDI within 2% for every row | 0 rows | 0 | A column is mis-mapped in staging |
| T3 | 04 | All-events SAIDI not lower than ex-MED SAIDI | 4 rows (known source anomalies, P8) | 4 | A different count means new anomalous rows. Investigate before using peer figures |
| T4 | 04 | Dominion VA 2025 equals EIA's published values (306.7, 144.4, 2,675,735) | 0 rows | 0 | Wrong file or wrong column mapping. Stop the refresh |
| T5 | 04 | Row count and customer total by year | 13 rows, 940 to 1,175 reporting units per year, customers increasing each year. The step from 1,175 (2019) to 941 (2020) reflects a change in which filers appear in the reliability table | 13 | A year with materially fewer rows indicates a parse failure |
| T6 | 04 | No raw numeric value failed `TRY_TO_NUMBER` after separator removal | 0 rows | 0 | A new formatting variant in the source. Extend the `REPLACE` |
| T7 | 05 | Every Dominion county in the service territory resolves to a FIPS code | 0 rows | 0 | A county spelling changed. Extend the name mapping |
| T8 | 05 | The latest NOAA file covers a full year | 1 row, month 12 | 202512 | The NOAA file is partial. Wait, or state the cut-off on the chart |
| T9 | 05 | No zone event left without a county after both passes | 0 rows | 0 | Further zone renumbering. Refresh the zone lookup |
| T10 | 06 | Hours with reported demand above 60,000 MW | 2 rows (18 October 2021) | 2 | Additional anomalous rows. Review the dates |
| T11 | 06 | No UTC hour appears twice for the DOM zone | 0 rows | 0 | A file was loaded twice. Truncate and reload |
| T12 | 06 | Each full year 2019 to 2025 has at least 8,700 reported hours | 0 rows | 0 | A six-month file is missing or truncated |

### Form of the tests

Each test is a `SELECT` that returns the expected row count when the data is sound. Any user with read access can run them. In Snowflake they can be scheduled as a `TASK` that writes results to a table the report reads (see `docs/07_governance_and_runbook.md`). The same checks translate directly to dbt tests.

### Not covered by the tests

- The accuracy of a utility's own filing. T2 checks internal consistency, not the reported customer count. EIA does not audit filings.
- Whether Dominion's own major-event rule excludes more or fewer days than IEEE 1366 would. Not testable from public data. Stated as a limitation on each peer chart.
- Outage causes, circuit-level detail and repeat-outage customers. Not available in any public source.
