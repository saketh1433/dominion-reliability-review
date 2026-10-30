# How to rerun the analysis

This file is for someone who wants to reproduce or refresh the project. It is **not required reading** for understanding the business findings.

## What is stored where?

- [`data/input/`](../data/input/) contains the smaller EIA/PUDL extracts.
- [`data/reference/`](../data/reference/) contains the geographic lookups and selected company figures.
- [`data/output/`](../data/output/) contains saved annual summaries.
- Large NOAA and EIA-930 source downloads are **not committed**. Download scripts place them in local `data/raw/`, which Git ignores.
- The Power BI `.pbix` file is also **not committed**.

## Reproducing the work

**Core EIA reliability analysis:** Run `python scripts/run_local_duckdb.py` to build the reliability tables from the committed inputs without Snowflake.

**Full analysis in Snowflake:** Load the source files into the `RELIABILITY` database and run [`sql/01` through `sql/08`](../sql/) in order. NOAA and EIA-930 require the extra downloads in [`scripts/`](../scripts/). Run the checks in [`sql/04_tests.sql`](../sql/04_tests.sql) and in the NOAA and demand SQL files before relying on a refreshed report.

**Refreshes:** EIA reliability is annual, NOAA can revise older events, and hourly EIA-930 files are updated more frequently. Recheck source dates, row counts and year filters before using new results.

## Access and security

The SQL includes a read-only role intended for Power BI. Passwords and keys should not be committed. The repository ignores credentials, large downloads and `.pbix` files.

The repository **documents a possible scheduled-test setup**, but the example in the runbook should not be described as an active production automation unless it has actually been deployed.

## Scope

This is a public-data exercise. It cannot independently audit utility filings, match every reported major-event exclusion to NOAA storms, or assess feeder-level investment performance.
