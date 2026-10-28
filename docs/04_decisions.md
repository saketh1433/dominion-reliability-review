# 04. Decisions

The judgement calls, in the order they were made. Each one records the alternative that was considered and why it lost, so a reviewer can disagree with a decision rather than wonder whether it was noticed.

Format: context, decision, alternatives, consequence.

---

### D1. Store additive numerators, never average ratios

**Context.** SAIDI, SAIFI and CAIDI are ratios. EIA publishes them per utility. Any comparison across utilities or years needs an aggregate.

**Decision.** `FCT_RELIABILITY` stores `cust_minutes_ex_med = saidi_ex_med x customers` and `cust_interruptions_ex_med = saifi_ex_med x customers`. Every aggregate sums these and divides by summed customers. In DAX the same rule is `DIVIDE(SUM(minutes), SUM(customers))`.

**Alternatives.** `AVG(saidi)` across utilities. Rejected: it weights a 5,000-customer co-op the same as Dominion. For the Virginia co-ops in 2025 the simple average is 2.44 interruptions per customer, the customer-weighted figure is 1.85.

**Consequence.** Three-year averages are the average of three annual customer-weighted values (`AVERAGEX(VALUES(YEAR), [SAIDI ex MED])`), which is how Dominion defines its three-year figure and reproduces 133.0.

---

### D2. Ex-MED is the headline measure, all-events is shown beside it

**Context.** EIA publishes both. Dominion reports the ex-MED number to the SCC and in its annual report.

**Decision.** Ex-MED is the number every trend and comparison uses, because it is the number the company is judged on. All-events appears on the scorecard and the stacked bars so the storm share is never hidden.

**Alternatives.** All-events as headline. Rejected: the series is dominated by whether a hurricane hit, which says little about the grid.

**Consequence.** Dominion files under its own major-event rule ("Other" standard), most large peers under IEEE 1366. The two are not identical and nothing public reconciles them. Every peer chart carries that caveat and the table shows the method per utility.

---

### D3. RAW is all VARCHAR, exactly as filed

**Context.** Source files mix "." blanks, thousands separators, mixed-case booleans and three header rows.

**Decision.** `COPY INTO` tables where every column is `VARCHAR`. Typing happens in STG views with `TRY_*` functions, so a bad value becomes NULL rather than failing the load and T6 reports any value that failed.

**Alternatives.** Typed RAW tables with `ON_ERROR = CONTINUE`. Rejected: rows silently vanish.

**Consequence.** RAW is a faithful copy. Any typing decision can be changed without reloading.

---

### D4. Weather is measured in county-days, not events

**Context.** NOAA records one row per event. A single squall line can generate forty Thunderstorm Wind rows in one county in one afternoon.

**Decision.** `STORM_INDEX` counts distinct (county, date) pairs with at least one line-risk event. 796 county-days in 2025.

**Alternatives.** Event counts (over-weights well-reported storms), damage dollars (sparse, inconsistent), heating and cooling degree days (temperature, not wind and the annual report already quotes them).

**Consequence.** The index correlates 0.70 with ex-MED SAIDI over 2015 to 2024 and 0.41 with SAIFI. It is a measure of exposure, not of damage.

---

### D5. Which NOAA event types count as line risk

**Decision.** Wind: Thunderstorm Wind, High Wind, Strong Wind, Tornado. Winter: Ice Storm, Winter Storm, Heavy Snow, Blizzard, Sleet. Tropical: Hurricane, Hurricane (Typhoon), Tropical Storm, Tropical Depression. Everything else (flood, heat, hail, lightning, drought) is `other` and excluded.

**Alternatives.** Include Lightning and Hail. Rejected: lightning is reported inconsistently across years, hail rarely takes lines down. Include Flash Flood. Rejected: floods damage substations, which show up as major events and are already excluded from ex-MED.

**Consequence.** A reviewer who disagrees changes one `CASE` expression in `STG.NOAA_VA_EVENTS`; nothing else moves.

---

### D6. The weather fit uses 2015 to 2024

**Context.** `SAIDI_WEATHER_ADJUSTED` needs a fitted relationship between storm days and SAIDI.

**Decision.** Fit on 2015 to 2024. Predict 2025 out of sample.

**Alternatives.** Include 2013 to 2014: rejected because the 2015 change to automated outage recording shifts the level. Include 2025: rejected because the point of the exercise is to test 2025 against a line it did not help draw.

**Consequence.** Ten points. The fit is a straight line with intercept 104.4 and slope 0.051 minutes per county-day. It is a check, not a forecasting model and is described that way.

---

### D7. Hourly demand above 60,000 MW is a reporting error

**Context.** Two hours in October 2021 report over a billion MW for the DOM zone.

**Decision.** Cap at 60,000 MW in `STG.EIA930_DOM_HOURLY`. The DOM zone has never exceeded 26,000; all of PJM peaks near 150,000. Reported values are kept in `demand_mw_reported`.

**Alternatives.** Replace with the neighbouring hours' average. Rejected: invents data. Drop the rows. Rejected: hides the finding.

---

### D8. Hourly data is keyed on UTC

**Decision.** `utc_ts` is the key for every hourly operation. Local time is kept for display.

**Reason.** Local time has 23- and 25-hour days at the clock changes. UTC does not. T11 proves no duplicates.

---

### D9. Top-50 hours are ranked twice

**Context.** Dominion's annual report says "38 of the 50 highest peak loads in DOM Zone history have occurred since 1 January 2025". The claim has a reference date.

**Decision.** `DOM_TOP50_HOURS` ranks hours as of 31 December 2025 (comparable to the report) and as of the load date. Both are kept; the dashboard card uses the first.

**Consequence.** 47 of 50 as of end 2025, 46 of 50 in 2026 as of October 2026. The EIA record starts July 2018, so older summers that sit in Dominion's own top 50 are absent, which is why 47 is higher than 38.

---

### D10. The peer set

**Decision.** Twelve large investor-owned utilities in PJM and the Southeast, chosen by ID before any results were seen: Duke Carolinas, Duke Progress, Georgia Power, Alabama Power, Dominion SC (Southeast). BGE, Pepco, PECO, PPL (Mid-Atlantic, PJM). FPL, Duke Energy Florida (Florida). Plus Dominion VA. Appalachian Power (VA) is kept as its own group and shown separately: its mountain terrain puts it above 300 minutes and it would squash every chart.

**Alternatives.** All IOUs over one million customers nationally. Rejected: California, Texas and the Northwest face different weather and vegetation, so the comparison would need a weather model this project does not have.

**Consequence.** "Fourth-highest of twelve" is a statement about this set. The table shows every member and its reporting method.

---

### D11. Two co-op benchmarks, one on the dashboard

**Decision.** `V_GROUP_INDEX` uses every Virginia cooperative, customer-weighted (what the dashboard shows). `V_VA_COOP_PANEL` is a balanced panel of the seven co-ops with at least 10,000 customers that filed every year 2015 to 2025, used in `03_analysis.sql` Q3 to check the result is not driven by entry and exit and Q3d leaves each co-op out in turn to check no single one drives it.

**Consequence.** Both give the same direction. The dashboard states "all Virginia co-ops combined".

---

### D12. Peer groups are assigned by EIA utility ID, not by name

**Reason.** Names change (Virginia Electric & Power Co is Dominion Energy Virginia). IDs do not. `DIM_UTILITY.peer_group` is a `CASE` on `(utility_id, state)`.

---

### D13. DirectQuery to build, Import to present

**Decision.** The report was built in DirectQuery against Snowflake so every change in the mart appeared immediately. Before presentation it is switched to Import so it opens with no network and no warehouse. The DirectQuery copy is kept as a separate file.

**Consequence.** The Import file carries a snapshot date in its title page.

---

### D14. What the project does not claim

- It does not estimate the effect of the grid transformation programme. It shows that the annual ex-MED number, weather-adjusted, has not moved and gives the arithmetic for why a programme covering under 3% of circuits could not move it by more than a few minutes. The co-op comparison is the nearest public data gets to an effect estimate and is presented as a direction, not a number.
- It does not rank Dominion nationally. It places it within a chosen peer set with methods stated.
- It does not attribute load growth to data centres by name. EIA-861 does not identify customers. It shows the shape of the growth (night faster than day, commercial sales far ahead of commercial customers) and notes that this is the shape round-the-clock load produces.
