# C-Suite — Dominion Energy Virginia reliability review

Executive-facing presentation and dashboard assets.

| Deliverable | Intended filename | Details |
|---|---|---|
| Interview / executive presentation | `Dominion_Reliability_Review.pptx` | Pending the latest PowerPoint supplied by the user. No presentation is created or modified as part of this change. |
| Executive Power BI report | `Dominion_Executive_Dashboards.pbix` | Two-page executive dashboard supplied 2026-11-02. |

The Power BI measures reference is maintained in [`../powerbi/measures.dax`](../powerbi/measures.dax). **The .dax file is documentation/source reference, not a patch automatically applied to the PBIX data model.** Edit embedded measures with Power BI Desktop or compatible model tools and validate the visuals before publishing.

Scope: public EIA-861 / PUDL, NOAA, EIA-930, and where applicable EAGLE-I; no Dominion private outage records. Major-event-day SAIDI is an EIA reporting difference, not verified storm damage.

Binary presentation and PBIX files are distributed separately if not shown in this folder; upload each via GitHub's Add file > Upload files control using the exact paths above.
