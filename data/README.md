# Data files

The original data files are stored separately from the supporting files and the results of my analysis making it easier to trace a number in the dashboard back to where it came from.

## What's in each folder?

| Folder | What it's for |
| --- | --- |
| [`input/`](input/) | Four EIA/PUDL extracts covering reliability, customer meters and electricity sales. The historical reliability file covers 2013–2024; the separate EIA file provides 2025. |
| [`reference/`](reference/) | Information used to interpret the data: Dominion's Virginia service counties, NOAA's weather-zone-to-county lookup, and selected figures from Dominion investor presentations. |
| [`output/`](output/) | Three exported summaries: annual storm exposure, storms alongside SAIDI, and annual demand for the PJM DOM subregion. |

## How I used the files

**Reliability:** I put the 2013–2024 history and 2025 EIA records into a consistent annual dataset. I used this to check Dominion's reported SAIDI, SAIFI and CAIDI trends.

**Weather:** NOAA records are filed by event, but several reports may describe weather affecting the same county on the same day. I matched the events to Dominion's Virginia service area using the files in `reference/`, then counted each county-date once. The result is [`storm_index.csv`](output/storm_index.csv). I matched these yearly totals with reported outage minutes in [`storm_vs_saidi.csv`](output/storm_vs_saidi.csv) for an exploratory regression.

**Electricity demand:** I filtered EIA-930 hourly records to the PJM DOM subregion, checked unusual readings, and summarized demand by year in [`dom_annual.csv`](output/dom_annual.csv). The DOM subregion is broader than Dominion's Virginia retail service area.

**Meters and sales:** The PUDL files in `input/` helped me compare smart-meter adoption, electricity use and customer growth. Those analyses don't have separate CSV exports in `output/`.

## Where are the full NOAA and hourly demand files?

They are too large to keep in this repository. The download scripts in [`scripts/`](../scripts/) retrieve them into a local `data/raw/` folder, which Git ignores. **So `raw/` won't appear in the GitHub folder listing.** The smaller files needed to reproduce the core reliability analysis are included here.

I didn't manually change numbers to make the charts. The cleaning and calculations are defined in [`sql/`](../sql/). For exact sources and file counts, see [Sources](../docs/01_sources.md); for worked examples showing how a source row becomes a result, see [Transformations](../docs/08_transformations.md).
