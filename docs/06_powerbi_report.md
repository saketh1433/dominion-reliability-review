# Power BI reports

The repository includes an executive report and a separate detailed analytical report. The source measures are documented in [`powerbi/measures.dax`](../powerbi/measures.dax).

| Report | Repository file | Focus |
|---|---|---|
| Executive dashboard | [`C-Suite/Dominion_Executive_Dashboards.pbix`](../C-Suite/Dominion_Executive_Dashboards.pbix) | Reliability results and management-level context |
| Detailed charts | [`powerbi/Dominion_Charts_Raw.pbix`](../powerbi/Dominion_Charts_Raw.pbix) | Reliability trends, weather relationships, peer performance and load patterns |

## Calculation principles

- **SAIDI:** total customer-interruption minutes divided by customers served.
- **SAIFI:** total customer interruptions divided by customers served.
- **CAIDI:** SAIDI divided by SAIFI.
- **Major-event-day SAIDI:** SAIDI including all events minus SAIDI excluding major-event days. This is an EIA reporting difference and is not equivalent to verified storm-related outage minutes.
- **Three-year SAIDI:** the arithmetic average of three reported annual SAIDI figures for the selected utility, not an average over separate non-overlapping periods.
- **Weather-adjusted SAIDI:** a model-based comparison derived from EIA and NOAA observations; it is not a published reliability index.

When aggregating across utilities, the reliability measures first sum customer-weighted numerators and denominators, then divide. Annual ratios should not be summed.

## Data sources

The core reliability model uses EIA-861 records standardized through PUDL for historical years and the EIA 2025 release. NOAA provides storm reports; EIA-930 provides hourly demand for the broader PJM DOM subregion. The source register and known limitations are in [`docs/01_sources.md`](01_sources.md) and [`docs/03_data_quality.md`](03_data_quality.md).

## Model and validation

The analysis is documented in [`sql/`](../sql/) with source transformations, reliability measures and validation queries. A local DuckDB runner checks the core reliability calculations. Additional weather and demand checks have separate inputs and processing requirements.

Both PBIX reports are binary report snapshots. The text measure reference in GitHub does not automatically update the measures or visuals inside those reports.
