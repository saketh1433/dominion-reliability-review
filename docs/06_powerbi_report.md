# 06. The Power BI report

File: `Dominion_Reliability.pbix` (not committed; see `docs/07_governance_and_runbook.md` for why and where it lives). Model: ten Snowflake objects from `RELIABILITY.MART` plus three workbook sheets. One relationship: `FCT_RELIABILITY[UTILITY_KEY]` many-to-one `DIM_UTILITY[UTILITY_KEY]`. Every other table stands alone, keyed by year or hour.

## Design rules applied on every page

| Rule | Why |
|---|---|
| Title states the finding, subtitle gives unit and source | A reader who only reads titles gets the whole story |
| Blue `#0A66C2` is the thing being judged (Dominion, the series the title is about). Grey `#B8BCC2` is context. Amber `#E8B117` only where a third category is needed (day hours, summer) | Colour means one thing across the report |
| Straight lines between annual points, markers on | Smoothing draws values that were never measured |
| Counting changes (2015, 2020) marked as dashed vertical lines on every reliability trend | Otherwise the 2016 and 2018 jumps look like performance |
| A reference line where the reader needs an anchor (2019 level, 2015 = 100, ten-year average, peer medians) | Non-zero axes are honest only with an anchor |
| Labels on the points the story names, not all of them | |
| Every number comes from a measure, never a dragged column | No "Sum of" in headers and aggregation is customer-weighted by construction |
| One headline text box per page, same position, same size | The six headlines read as the six sentences of the story |

## Pages

### 0. Summary
One page that answers the three questions leadership asked in 2025, one column each. Built from copies of visuals on the other pages.

| Column | Question | Visuals |
|---|---|---|
| 1 | Was 2025 the grid or the weather? | Card 133 (ties to report), card 53% storm share, stacked columns (ordinary vs major event days), cards "weather predicts 145 / actual 144" |
| 2 | Is the grid getting better underneath? | Weather-adjusted line (flat at 134), co-op index (137 vs 114), text: hardening covers about 3% of circuits, worth 2 to 4 minutes against a 15-minute yearly swing |
| 3 | What is the load doing? | Cards +52% base load and 47 of 50, hour-of-day columns, smart meter bars |

### 1. Scorecard
Headline: *2025 in Dominion's own measure: 133 minutes, up from 130 and the public data ties to the annual report.*
Page filter: `PEER_GROUP` = Dominion Energy Virginia, `YEAR` = 2025. Seven cards (`docs/05`), one reconciliation table from the workbook (`Reconciliation` sheet: metric, rebuilt value, annual report value, report page).

### 2. What moved
Headline: *Restoration got faster after 2019. Frequency rose after 2023.*
Two line charts side by side (SAIFI ex-MED, CAIDI ex-MED), 2013 to 2025, with the 2015 and 2020 lines and a dotted 2019 level. Two cards: outage frequency 2019 to 2025 (+6%), restoration time 2019 to 2025 (-9%).

### 3. Weather
Headline: *Storms are half the minutes. The 2025 rise is the weather and underneath the weather nothing has moved.*
Four visuals making one argument: stacked columns (storms matter), scatter with trend line (how much: 0.70), weather-adjusted line (what is left: flat), co-op index (same weather, better outcome).

### 4. Fair comparison
Headline: *Fourth of twelve on outage minutes. Restoration speed is competitive, frequency is the gap and half the peers measure differently.*
Bar chart (twelve peers, three-year average, best at top), quadrant scatter (all twelve dots, names only in Dominion's quadrant, dashed lines at the peer medians), table (region, storm rule, two period averages, change, five-year SAIFI and CAIDI, Dominion row shaded).

### 5. Growth
Headline: *Load is growing fastest at night. The hardware is in, the demand side is not being used yet.*
Hour-of-day columns (lead), three cards, winter/summer columns, sales index line, smart meter bars.

### 6. Data notes
Headline: *What was checked and what the public data cannot say.*
Table of the twelve tests with result and note (from the `Tests` sheet, or from `MART.TEST_RESULTS` if the Snowflake task is set up). Text box with method notes and sources.

## Model objects and where each is used

| Object | Mode | Pages |
|---|---|---|
| `DIM_UTILITY` | Snowflake | 1, 2, 3, 4 (filters, peer groups, names) |
| `FCT_RELIABILITY` | Snowflake | 1, 2, 3, 4 (every reliability measure) |
| `V_TREND` | Snowflake | available for drill-down; the report uses measures on FCT instead |
| `V_GROUP_INDEX` | Snowflake | 3 (co-op index) |
| `STORM_INDEX`, `V_STORM_VS_SAIDI` | Snowflake | 3 (scatter) |
| `SAIDI_WEATHER_ADJUSTED` | Snowflake | 3, 0 |
| `DOM_LOAD_ANNUAL`, `DOM_TOP50_HOURS`, `DOM_LOAD_PROFILE` | Snowflake | 5, 0 |
| `LoadGrowth`, `Programmes2025`, `Reconciliation`, `Tests` | workbook sheets | 1, 5, 6 |

## Refresh

DirectQuery copy: open the file, Home > Refresh, every visual re-queries Snowflake. Import copy: Home > Refresh pulls a new snapshot; takes under a minute on an X-Small warehouse. The service account and its rights are in `docs/07`.

## Export

File > Export > PDF produces the static copy used as the presentation backup. Every page is designed to read at A4 landscape.
