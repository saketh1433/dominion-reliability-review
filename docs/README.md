# How to read this project

This folder explains the reasoning behind the Dominion reliability review. You do **not** need to read everything to understand the project.

Start here:

1. [What the numbers mean](05_metrics_and_measures.md) — SAIDI, SAIFI, CAIDI, and the main results.
2. [How the analysis was done](08_transformations.md) — three real examples, from source data to a result.
3. [What I checked](03_data_quality.md) — cleaning choices and checks.
4. [Why I made those choices](04_decisions.md) — strengths and limits of the analysis.
5. [What the charts show](06_powerbi_report.md) — how to read the Power BI pages.

For reference: [Sources](01_sources.md), [Tables and columns](02_data_dictionary.md), [File naming](00_conventions.md), and [How to rerun it](07_governance_and_runbook.md).

## In one paragraph

I used public utility reliability reports to understand whether Dominion's outage-minutes trend was driven more by **more interruptions** or **longer interruptions**. I then checked how recorded storm exposure lined up with annual outage minutes and looked separately at changing hourly electricity demand. SQL helped me make inconsistent source files comparable; Power BI helped me communicate the results. This is a **public-data investigation**, not a feeder-level assessment or a causal estimate of the effect of storms.

The original files are under [`data/`](../data/) and the calculations are in [`sql/`](../sql/). These notes explain those files; they are not the calculations themselves.
