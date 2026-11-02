# C-Suite — Dominion Energy Virginia reliability review

Executive-facing presentation and dashboard assets.

| Deliverable | Intended filename | Details |
|---|---|---|
| Interview / executive presentation | `Dominion_Reliability_Review.pptx` | Latest 16-slide review with updated NOAA storm county-day counts (2023 390, 2024 464, 2025 791), corrected 2015–2024 fitted coefficients (104.3 + 0.0518 × county-days), and one-count Bedford county mapping. |
| Executive Power BI report | `Dominion_Executive_Dashboards.pbix` | Two-page executive dashboard supplied 2026-11-02. |

The Power BI measures reference is maintained in [`../powerbi/measures.dax`](../powerbi/measures.dax). **The .dax file is documentation/source reference, not a patch automatically applied to the PBIX data model.** Edit embedded measures with Power BI Desktop or compatible model tools and validate the visuals before publishing.

Scope: public EIA-861 / PUDL, NOAA, EIA-930, and where applicable EAGLE-I; no Dominion private outage records. Major-event-day SAIDI is an EIA reporting difference, not verified storm damage.

Binary presentation and PBIX files are distributed separately if not shown in this folder; upload each via GitHub's Add file > Upload files control using the exact paths above.
