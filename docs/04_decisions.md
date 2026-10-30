# Why I analyzed the data this way

These were the main choices behind the review. The aim was to make reasonable comparisons without claiming more than the public data can show.

| Decision | Why I made it | Limitation |
| --- | --- | --- |
| Use SAIDI **excluding major event days** for the main reliability trend | Matches the headline measure Dominion reports | Exclusion rules differ among utilities |
| Compare SAIFI and CAIDI alongside SAIDI | Separates **how often** customers lose power from **how long** interruptions last | Doesn't identify outage causes |
| Weight peer measures by customers, not by utilities | A small utility shouldn't count as much as one serving millions | Peers differ in geography, storms and reporting rules |
| Count NOAA **storm county-days**, not individual event reports | One storm can create multiple NOAA records in the same county/date | A county-day doesn't measure damage or customer exposure |
| Use wind, winter and tropical event categories | Focus on weather plausibly relevant to overhead lines | Some relevant events may be missed; classifications are simplified |
| Fit a simple weather model on **2015–2024** and hold out **2025** | Avoid the known 2015 reporting break and test on a later year | Only ten training observations and no controls for other reliability factors |
| Analyze PJM's **DOM subregion** separately from utility-level reliability | Hourly demand shows changing load patterns | The DOM region is not identical to Dominion's Virginia retail service area |
| Keep reporting errors visible | Makes the cleaning decisions auditable | Some missing values remain unresolved |

## What I would do differently with internal data

I would examine **feeder-level interruptions**, equipment condition, outage causes, weather by location, vegetation work and maintenance history. That could help separate the influence of storms from recurring operational problems and evaluate potential improvements.

**Bottom line:** These are exploratory comparisons, not a causal study or a recommendation to upgrade a particular circuit. Exact implementation is in [the SQL](../sql/); the calculations are explained in [Metrics](05_metrics_and_measures.md).
