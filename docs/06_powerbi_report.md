# Reading the Power BI report

The dashboard answers three questions: **What changed in reliability? How does weather relate to it? How is electricity demand changing?** It is a way to communicate the analysis, not a substitute for the underlying data.

| Page | Main question | What to take away |
| --- | --- | --- |
| **Summary** | What's the overall picture? | The rolling three-year SAIDI average increased from about 130 to 133 minutes; other charts provide context |
| **Scorecard** | Do the public numbers match Dominion's reported figures? | The EIA reliability figures reproduce the main annual-report measure |
| **What moved** | More interruptions or longer ones? | Frequency rose more sharply than duration from 2023 to 2025 |
| **Weather** | Do stormier years tend to have more outage minutes? | A positive historical association, **not proof** of cause |
| **Fair comparison** | How does Dominion compare with selected utilities? | Useful context, but differences in geography and storm-exclusion rules limit rankings |
| **Growth** | Is the load profile changing? | Both peak and minimum hourly demand increased in PJM's DOM subregion |
| **Data notes** | What should readers be cautious about? | Reporting differences, missing internal data and modelling limitations |

## Three charts I'd explain first

1. **SAIFI and CAIDI trends:** the clearest insight is that the recent SAIDI increase is more frequency-driven.
2. **Storm exposure versus SAIDI:** shows how external NOAA records can add context, while acknowledging the regression's limits.
3. **Hourly demand profile:** shows rising electricity demand even outside the peak hours, relevant to broader planning questions.

## Wording to use carefully

- Say **“major-event-day minutes”**, not necessarily **“NOAA storm-caused minutes.”**
- Say **“associated with weather exposure”**, not **“weather caused the increase.”**
- Say **“commercial sales grew faster than customer counts”**, not **“data centres caused the entire gap.”**
- Say **“minimum hourly demand”**, not **“base load”** when referring to the annual lowest hour.
- Label **2026 demand** as year-to-date; it is not a complete year.

The dashboard was built using Snowflake analysis tables and some workbook sheets. A `.pbix` file is **not stored in GitHub**; see [Data files](../data/) and [Metrics](05_metrics_and_measures.md) for the numbers behind the charts.

**What I'd investigate next:** With internal feeder-level outage, asset and maintenance records, identify repeat interruption causes and evaluate where preventive work might help.
