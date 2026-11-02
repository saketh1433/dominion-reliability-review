# Power BI reports and DAX

- `measures.dax`: latest **reference definitions** for the report, including updated customer-weighted reliability measures, major-event reporting labels, executive selected-year KPI measures, weather comparisons, demand, and outage context.
- `Dominion_Charts_Raw.pbix`: six-page analytical report supplied 2026-11-02 (Scorecards, What Moved, Weather, Peer Comparison, Growth, Seasonal). Upload the binary here if it does not appear in the repository.

The separately supplied `Dominion_Executive_Dashboards.pbix` belongs under [`../C-Suite/`](../C-Suite/).

**Important:** GitHub text changes to `measures.dax` do **not** modify the measures embedded in an existing `.pbix` file. The report files contain embedded model data and should be kept intact. Updating in-report measures requires Power BI Desktop / compatible model tooling; validate all dependent visuals afterwards.

Use **Major-event-day SAIDI** for `SAIDI all events - SAIDI ex MED`. Avoid presenting any legacy "Storm SAIDI" or "caused by major storms" title as verified weather attribution.

Source model aligned with the public review at [Renvia-code/Sab-Dominion](https://github.com/Renvia-code/Sab-Dominion); DAX definitions extended to match measures referenced by the two reports supplied on 2026-11-02.
