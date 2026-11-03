# Power BI reports

| File | Purpose |
|---|---|
| [Dominion_Charts_Raw.pbix](Dominion_Charts_Raw.pbix) | Detailed analytical charts covering reliability, weather, peer comparisons and electricity demand |
| [measures.dax](measures.dax) | DAX measure reference and calculation definitions |
| [Dominion_Reliability_PowerBI_Data.xlsx](Dominion_Reliability_PowerBI_Data.xlsx) | Supporting Power BI workbook |

The [executive dashboard](../C-Suite/Dominion_Executive_Dashboards.pbix) is maintained with the [executive presentation](../C-Suite/Dominion%20Reliability%20Review.pptx).

## Measurement conventions

Reliability indices are customer-weighted where aggregating across reporting utilities. SAIDI including all events minus SAIDI excluding major-event days is a **major-event-day reporting difference**, not independently verified storm damage. Weather-adjusted SAIDI is an exploratory model output, not an EIA-reported measure.

The DAX file is a source reference. Changes to it do not automatically modify measures embedded in the PBIX files; embedded measures and visuals must be validated in Power BI before publication.

See [calculation definitions](../docs/05_metrics_and_measures.md) and [report documentation](../docs/06_powerbi_report.md).
