# 06. Power BI report

Report file: `Dominion_Reliability.pbix` (not committed; see `docs/07_governance_and_runbook.md`). Model: ten objects from `RELIABILITY.MART` and three workbook sheets. One relationship: `FCT_RELIABILITY[UTILITY_KEY]` many-to-one `DIM_UTILITY[UTILITY_KEY]`. All other tables are keyed by year or hour and have no relationships.

## Design rules

| Rule | Reason |
|---|---|
| Title states the finding. Subtitle states unit and source | The titles summarise the report on their own |
| `#0A66C2` for the subject of the chart (Dominion, or the series the title refers to); `#B8BCC2` for context; `#E8B117` only where a third category is required (day hours, summer) | Consistent colour meaning across pages |
| Straight lines between annual points, markers shown | Smoothed lines imply values between the annual observations |
| Counting changes (2015, 2020) marked as dashed vertical lines on each reliability trend | Separates changes in measurement from changes in performance |
| Reference line where an anchor is needed (2019 level, 2015 = 100, ten-year average, peer medians) | Makes non-zero axes readable |
| Data labels on the points referred to in the title | Reduces clutter |
| All figures come from measures, not dragged columns | No "Sum of" headers. Aggregation is customer-weighted |
| One headline text box per page, same position and size | Consistent layout |

## Pages

### 0. Summary
Three columns, one question each. Visuals are copies of those on the other pages.

| Column | Question | Visuals |
|---|---|---|
| 1 | Was the 2025 increase explained by weather? | Card 133 (matches report), card 53% storm share, stacked columns (ordinary vs major event days), cards "predicted from weather 145 / actual 144" |
| 2 | What is the weather-adjusted trend? | Weather-adjusted line (about 134 throughout), co-op index (137 vs 114), text box on hardening coverage (about 3% of circuits, 2 to 4 minutes against a yearly weather swing of about 15) and on the biennial review (authorised ROE 9.80%, performance adjustment of plus or minus 0.50% with reliability among the criteria) |
| 3 | How is the load changing? | Cards +52% base load and 47 of 50, hour-of-day columns, smart meter bars |

### 1. Scorecard
Headline: *2025 in Dominion's own measure: 133 minutes, up from 130 and the public data matches the annual report.*
Page filter: `PEER_GROUP` = Dominion Energy Virginia, `YEAR` = 2025. Seven cards (`docs/05`) and a reconciliation table from the workbook (`Reconciliation` sheet: metric, rebuilt value, annual report value, report page).

### 2. What moved
Headline: *Restoration time fell after 2019. Frequency rose after 2023.*
Two line charts (SAIFI ex-MED, CAIDI ex-MED), 2013 to 2025, with the 2015 and 2020 lines and a dotted 2019 level. Two cards: outage frequency 2019 to 2025 (+6%), restoration time 2019 to 2025 (-9%).

### 3. Weather
Headline: *Storms are half the minutes. The 2025 rise is explained by weather. The weather-adjusted series is unchanged.*
Stacked columns (ordinary vs major event days), scatter with trend line (correlation 0.70), weather-adjusted line, co-op index.

### 4. Fair comparison
Headline: *Fourth of twelve on outage minutes. Restoration time is mid-range. Frequency is the gap. Half the peers use a different reporting method.*
Bar chart (twelve peers, three-year average, ascending), quadrant scatter (all twelve utilities, labels in Dominion's quadrant, dashed lines at the peer medians), table (region, storm rule, two period averages, change, five-year SAIFI and CAIDI, Dominion row shaded).

### 5. Growth
Headline: *Load is growing fastest at night. Smart meters are installed. Time-varying rates are not in use.*
Hour-of-day columns, three cards, winter/summer columns, sales index line, smart meter bars. Optional: stacked columns of data centre contracted capacity by stage (SELOA, CLOA, ESA) from `dominion_ir_series.csv`, July 2023 to July 2026.

### 6. Data notes
Headline: *What was checked and what public data cannot show.*
Table of the twelve tests with result and note (from the `Tests` sheet, or from `MART.TEST_RESULTS` once the Snowflake task is in place). Text box with method notes and sources.

## Model objects

| Object | Source | Pages |
|---|---|---|
| `DIM_UTILITY` | Snowflake | 1, 2, 3, 4 (filters, peer groups, names) |
| `FCT_RELIABILITY` | Snowflake | 1, 2, 3, 4 (reliability measures) |
| `V_TREND` | Snowflake | Available for drill-down; the report uses measures on `FCT_RELIABILITY` |
| `V_GROUP_INDEX` | Snowflake | 3 (co-op index) |
| `STORM_INDEX`, `V_STORM_VS_SAIDI` | Snowflake | 3 (scatter) |
| `SAIDI_WEATHER_ADJUSTED` | Snowflake | 0, 3 |
| `DOM_LOAD_ANNUAL`, `DOM_TOP50_HOURS`, `DOM_LOAD_PROFILE` | Snowflake | 0, 5 |
| `LoadGrowth`, `Programmes2025`, `Reconciliation`, `Tests` | Workbook sheets | 1, 5, 6 |
| `dominion_ir_series` | `data/reference/dominion_ir_series.csv` | 0, 5 (contracted capacity, rate review text) |

## Refresh

DirectQuery copy: Home > Refresh re-queries Snowflake. Import copy: Home > Refresh loads a new snapshot (under one minute on an X-Small warehouse). Service account and permissions: `docs/07`.

## Export

File > Export > PDF produces the static copy. Pages are laid out for A4 landscape.
