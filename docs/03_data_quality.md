# 03. Data quality

Two layers: what was found when the raw files were profiled (and how each issue is handled in code), then the twelve tests that run after every load.

## Profiling findings and their fixes

Each of these was found by looking before typing (`sql/00_look_first.sql`) or by a test failing on the first run. Every fix lives in SQL, not in a hand-edited file, so the next load gets it for free.

| # | Source | Finding | Fix | Where |
|---|---|---|---|---|
| P1 | EIA-861 2025 | Three header rows, blanks written as "." | File format `SKIP_HEADER = 3`, `NULL_IF = ('.')` | `01`, `FF_EIA_CSV` |
| P2 | EIA-861 2025 | Numbers carry thousands separators ("2,675,735") | `TRY_TO_NUMBER(REPLACE(x, ',', ''))` in every typed column | `01`, `STG.RELIABILITY_2025` |
| P3 | EIA-861 2025 | Two blocks side by side (IEEE filers, Other filers); a utility fills one | Unpivot with `UNION ALL`, `standard` column records which | `01` |
| P4 | EIA-861 2025 | Eight utilities report ex-MED but no all-events figure | Kept. `WHERE ... OR saidi_ex_med IS NOT NULL` so they are not dropped | `01` |
| P5 | PUDL | Both standards appear as rows for every utility even when one is empty | Drop rows with no SAIDI in either column | `01`, `STG.RELIABILITY_HIST` |
| P6 | PUDL + EIA union | Seven small utilities filed both standards in 2021 | De-duplicate with `QUALIFY ROW_NUMBER() ... = 1`, IEEE row wins, so customers are not double counted | `01`, `STG.RELIABILITY` |
| P7 | EIA-861 | Counting rule changes in 2015 (automated outage recording) and 2020 (46 kV lines included) move Dominion's series | Not corrected in data, because they are real changes in what is measured. Marked on every trend chart as dashed lines and 2013 to 2014 excluded from the weather fit | charts, `07` |
| P8 | EIA-861 | Four utility-years in EIA's own file where all-events SAIDI is less than ex-MED SAIDI, which is impossible | Kept in `FCT_RELIABILITY` so the load ties to EIA; excluded from peer sets by the `Other` peer group. Test T3 reports them every run | `04`, T3 |
| P9 | NOAA | Zone events (`cz_type = 'Z'`) carry a forecast zone, not a county | Spread to counties through NOAA's zone-county lookup | `05`, `STG.NOAA_VA_EVENTS` |
| P10 | NOAA | 140 zone events referenced zones renumbered after the lookup was built | Second pass matches on `UPPER(cz_name)` to the county name. T9 confirms none remain | `05`, T9 |
| P11 | NOAA vs EIA | County name spellings differ ("Alexandria City" vs "City of Alexandria") and two counties really are called James City and Charles City | Both spellings tried, `MIN(fips)` per EIA county. T7 confirms all 104 found | `05`, T7 |
| P12 | NOAA | One storm can produce dozens of event rows in one county on one day | Index counts county-days, not events | `05`, `STORM_INDEX` |
| P13 | EIA-930 | Two hours on 18 Oct 2021 report 1.5 billion and 1.0 billion MW for a zone that peaks near 25,000 | Values above 60,000 MW set to NULL in staging; the reported value kept in `demand_mw_reported`. T10 lists them | `06`, T10 |
| P14 | EIA-930 | 2,020 hours have no demand value (1,729 of them in 2018, before reporting settled) | Left NULL. `hours_missing` recorded per year in `DOM_LOAD_ANNUAL`. T12 checks every full year has at least 8,700 reported hours | `06`, T12 |
| P15 | EIA-930 | Local time has 23- and 25-hour days at clock changes | All hourly logic keyed on `utc_ts`. T11 confirms no duplicate hour | `06`, T11 |
| P16 | EIA-930 | `EIA930_SUBREGION_2018_Jan_Jun.csv` is served as an HTML error page (subregion data starts July 2018) | Not loaded. Download script skips it. COPY `PATTERN` would reject it anyway | `scripts/download_eia930.sh` |
| P17 | EIA-861 vs annual report | EIA customers for Dominion VA are 2,675,735 and the report says 2,809k | Not an error: the report adds North Carolina. Stated on the scorecard card | dashboard |

## The tests

Run after every load. "Expected" is what a sound load returns. Anything else stops the refresh until explained.

| Test | File | Checks | Expected | Result on this build | Action if it fails |
|---|---|---|---|---|---|
| T1 | 04 | No duplicate utility-state-year in `FCT_RELIABILITY` | 0 rows | 0 | De-duplication in `STG.RELIABILITY` broke, or a new file overlaps years already loaded |
| T2 | 04 | SAIDI = SAIFI x CAIDI within 2% for every row | 0 rows | 0 | A column was mis-mapped in staging (the identity fails if ex-MED and all-events were swapped) |
| T3 | 04 | All-events SAIDI is never less than ex-MED SAIDI | 0 rows in principle. 4 known rows in EIA's own file | 4 | If the count changes, new impossible rows arrived. Investigate before trusting peer figures |
| T4 | 04 | Dominion VA 2025 matches EIA's published row (306.7, 144.4, 2,675,735) | 0 rows | 0 | The load is reading the wrong file or wrong columns. Stop. |
| T5 | 04 | Row count and customer total by year | 13 rows, no year missing, between about 940 and 1,175 reporting units a year. The step down from 1,175 (2019) to 941 (2020) is a known change in which filers appear in the reliability table, not a parse failure. Customers rise every year | 13 | A year with far fewer rows means a parse failure on that file |
| T6 | 04 | No raw numeric value failed `TRY_TO_NUMBER` after separator stripping | 0 rows | 0 | A new formatting quirk in the source. Look at the values, extend the `REPLACE` |
| T7 | 05 | Every Dominion county in the service territory found a FIPS code | 0 rows | 0 | EIA changed a county spelling. Add it to the name mapping |
| T8 | 05 | The latest NOAA file is a full year | 1 row showing month 12 | 202512 | NOAA's file is partial. Either wait or state the cut-off on the chart |
| T9 | 05 | No zone event left without a county after both passes | 0 rows | 0 | NOAA renumbered more zones. Refresh the zone lookup |
| T10 | 06 | Hours with demand above 60,000 MW | 2 known rows (18 Oct 2021) | 2 | More rows means EIA has new bad data. The cap handles it but look at the dates |
| T11 | 06 | No UTC hour appears twice for the DOM zone | 0 rows | 0 | A file was loaded twice. Truncate and re-COPY |
| T12 | 06 | Every full year 2019 to 2025 has at least 8,700 reported hours | 0 rows | 0 | A six-month file is missing or truncated |

### Why tests are queries, not a tool

Every test is a plain `SELECT` that returns zero rows when the data is sound. That is deliberate: anyone with read access can run them, they need no framework and in Snowflake they can be wrapped in a `TASK` that runs after the October EIA release and writes its results to a table the dashboard reads (`docs/07_governance_and_runbook.md`). If this were a team repository the same queries would move into dbt tests or Great Expectations without changing what they check.

### What the tests do not cover

- Whether a utility's own numbers are right. T2 catches internal inconsistency, not a wrong count of customers. EIA does not audit filings.
- Whether Dominion's "Other" storm rule excludes more or fewer days than IEEE 1366 would. Nothing in the public data can test that, so it is stated as a limitation on every peer chart.
- Causes of outages, circuit-level detail, repeat-outage customers. Not in any public source.
