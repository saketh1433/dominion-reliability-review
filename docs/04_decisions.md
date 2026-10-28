# 04. Decisions

Design decisions, each with context, the decision, alternatives considered and consequences.

---

### D1. Aggregation uses additive numerators

**Context.** SAIDI, SAIFI and CAIDI are ratios published per utility. Comparisons across utilities or years require an aggregate.

**Decision.** `FCT_RELIABILITY` stores `cust_minutes_ex_med = saidi_ex_med x customers` and `cust_interruptions_ex_med = saifi_ex_med x customers`. Aggregates sum these and divide by summed customers. In DAX: `DIVIDE(SUM(minutes), SUM(customers))`.

**Alternatives.** `AVG(saidi)` across utilities. Rejected: it weights every utility equally regardless of size. For the Virginia co-ops in 2025 the simple average SAIFI is 2.44 and the customer-weighted figure is 1.89.

**Consequence.** Multi-year averages are averages of annual customer-weighted values (`AVERAGEX(VALUES(YEAR), [SAIDI ex MED])`), which matches Dominion's definition of its three-year figure and reproduces 133.0.

---

### D2. Ex-MED is the headline measure, with all-events shown alongside

**Context.** EIA publishes both. Dominion reports the ex-MED figure to the SCC and in its annual report.

**Decision.** Trends and comparisons use ex-MED. All-events appears on the scorecard and in the stacked bar chart so that the storm share is visible.

**Alternatives.** All-events as the headline. Rejected: the series is dominated by major storms and does not describe day-to-day performance.

**Consequence.** Dominion files under its own major-event rule (EIA "Other" standard). Most large peers file under IEEE 1366. The two are not reconciled by any public source. Each peer chart carries this caveat and the peer table shows the method per utility.

---

### D3. RAW tables are all VARCHAR

**Context.** Source files contain "." for blanks, thousands separators, mixed-case booleans and multiple header rows.

**Decision.** `COPY INTO` tables in which every column is `VARCHAR`. Typing is done in STG views with `TRY_*` functions; a value that fails typing becomes NULL and T6 reports it.

**Alternatives.** Typed RAW tables with `ON_ERROR = CONTINUE`. Rejected: rows are dropped without a record.

**Consequence.** RAW is an exact copy of the source. Typing rules can be changed without reloading.

---

### D4. Weather exposure is measured in county-days

**Context.** NOAA records one row per event. A single storm can produce many rows in one county on one day.

**Decision.** `STORM_INDEX` counts distinct (county, date) pairs with at least one line-risk event. 796 county-days in 2025.

**Alternatives.** Event counts (over-weight well-reported storms). Damage estimates (sparse and inconsistent). Heating and cooling degree days (temperature only and already quoted in the annual report).

**Consequence.** The index correlates 0.70 with SAIDI ex-MED over 2015 to 2024 and 0.41 with SAIFI. It measures exposure, not damage.

---

### D5. Event types classified as line risk

**Decision.** Wind: Thunderstorm Wind, High Wind, Strong Wind, Tornado. Winter: Ice Storm, Winter Storm, Heavy Snow, Blizzard, Sleet. Tropical: Hurricane, Hurricane (Typhoon), Tropical Storm, Tropical Depression. All other types (flood, heat, hail, lightning, drought) are classified `other` and excluded.

**Alternatives.** Include Lightning and Hail. Rejected: lightning reporting is inconsistent across years and hail rarely causes line outages. Include Flash Flood. Rejected: flood damage affects substations and appears in major event days, which ex-MED already excludes.

**Consequence.** The classification is one `CASE` expression in `STG.NOAA_VA_EVENTS`.

---

### D6. Weather fit window is 2015 to 2024

**Context.** `SAIDI_WEATHER_ADJUSTED` requires a fitted relationship between storm county-days and SAIDI.

**Decision.** Fit on 2015 to 2024 and predict 2025 out of sample.

**Alternatives.** Include 2013 and 2014. Rejected: the 2015 change to automated outage recording shifts the level. Include 2025. Rejected: 2025 is the year under test.

**Consequence.** Ten observations. Intercept 104.4, slope 0.051 minutes per county-day. The fit is a check on one year, not a forecasting model.

---

### D7. Hourly demand above 60,000 MW is treated as a reporting error

**Context.** Two hours in October 2021 report over one billion MW for the DOM zone.

**Decision.** Values above 60,000 MW are set to NULL in `STG.EIA930_DOM_HOURLY`. The DOM zone has not exceeded 26,000 MW; PJM as a whole peaks near 150,000 MW. Reported values are retained in `demand_mw_reported`.

**Alternatives.** Replace with the mean of neighbouring hours. Rejected: fabricates data. Drop the rows. Rejected: removes the record of the anomaly.

---

### D8. Hourly data is keyed on UTC

**Decision.** `utc_ts` is the key for all hourly operations. Local time is retained for display.

**Reason.** Local time has 23-hour and 25-hour days at clock changes. T11 confirms no duplicate hours.

---

### D9. Top-50 hours are ranked at two reference dates

**Context.** Dominion's annual report states that 38 of the 50 highest peak loads in DOM Zone history occurred after 1 January 2025. The statement has a reference date.

**Decision.** `DOM_TOP50_HOURS` ranks hours as of 31 December 2025 (comparable with the report) and as of the load date. The report card uses the first.

**Consequence.** 47 of 50 as of end 2025 and 46 of 50 as of October 2026. The EIA record starts in July 2018, so earlier years present in Dominion's own ranking are absent, which accounts for 47 exceeding 38.

---

### D10. Peer set

**Decision.** Twelve large investor-owned utilities in PJM and the Southeast, selected by EIA ID before results were computed. Southeast: Duke Carolinas, Duke Progress, Georgia Power, Alabama Power, Dominion SC. Mid-Atlantic (PJM): BGE, Pepco, PECO, PPL. Florida: FPL, Duke Energy Florida. Plus Dominion VA. Appalachian Power (VA) is held in a separate group and shown separately because its SAIDI exceeds 300 minutes and would compress the scale of every chart.

**Alternatives.** All investor-owned utilities with over one million customers nationally. Rejected: differences in climate and vegetation across regions would require a weather model outside the scope of this project.

**Consequence.** Rankings are statements about this set only. The peer table lists every member and its reporting method.

---

### D11. Two co-op benchmarks

**Decision.** `V_GROUP_INDEX` uses all Virginia cooperatives, customer-weighted; this is the series on the report. `V_VA_COOP_PANEL` is a balanced panel of the seven co-ops with at least 10,000 customers that filed in every year 2015 to 2025, used in `03_analysis.sql` Q3 to check that the result is not driven by entry and exit. Q3d repeats the comparison leaving each co-op out in turn.

**Consequence.** Both benchmarks give the same direction. The report states "all Virginia co-ops combined".

---

### D12. Peer groups are assigned by EIA utility ID

**Reason.** Utility names change (Virginia Electric & Power Co trades as Dominion Energy Virginia); IDs do not. `DIM_UTILITY.peer_group` is a `CASE` on `(utility_id, state)`.

---

### D13. DirectQuery during development, Import for presentation

**Decision.** The report was developed in DirectQuery against Snowflake. For presentation it is switched to Import so that it opens without a network connection or a running warehouse. The DirectQuery copy is retained separately.

**Consequence.** The Import file carries a snapshot date on its title page.

---

### D14. Scope limits

- The project does not estimate the effect of the grid transformation programme. It reports that weather-adjusted SAIDI ex-MED is within the noise of the fit across 2015 to 2025 and notes that a programme covering under 3% of circuits could not move the annual figure by more than a few minutes. The co-op comparison indicates direction, not magnitude.
- The project does not rank Dominion nationally. It places Dominion within a defined peer set with reporting methods stated.
- The project does not attribute load growth to data centres from the data. EIA-861 does not identify customers. It reports the shape of the growth (night hours rising faster than day hours and commercial sales rising far faster than commercial customer counts), which is consistent with round-the-clock load.
