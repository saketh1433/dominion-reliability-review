# 00. Conventions

> **At a glance:** Quick read: these are naming rules for files, SQL objects and charts. They are reference material, not part of the business conclusions.

Naming rules for the repository, the Snowflake objects, the Power BI model and git.

## Repository and folders

- Repository: `dominion-reliability-review`, kebab-case.
- Folders: lowercase, one word: `sql/`, `docs/`, `scripts/`, `data/`, `powerbi/`.
- Under `data/`: `input/` (files as loaded), `reference/` (lookups), `output/` (derived tables), `raw/` (large downloads, ignored by git).

## SQL files

- `NN_<content>.sql`, two-digit run order, snake_case.
- One file covers one layer (01 raw and staging, 02 mart, 04 tests) or one source (05 NOAA, 06 EIA-930).
- Analysis queries are in 03 or at the end of a source file. Grants are in 08.
- Expected row counts and results are stated in a comment beside the statement that produces them.

## Snowflake objects

Upper case, as Snowflake displays them.

| Object | Pattern | Examples |
|---|---|---|
| Database, schemas | `RELIABILITY`; `RAW`, `STG`, `MART` | |
| File formats | `FF_<SOURCE>_CSV` | `FF_EIA_CSV`, `FF_NOAA_CSV`, `FF_EIA930_CSV` |
| Stages | `<SOURCE>_STAGE` | `EIA_STAGE`, `PUDL_STAGE`, `NOAA_STAGE`, `EIA930_STAGE` |
| RAW tables | `<SOURCE>_<TABLE>[_<YEAR>]`, one per source file, all columns VARCHAR | `EIA861_RELIABILITY_2025`, `PUDL_SALES`, `NOAA_STORM_EVENTS`, `EIA930_SUBREGION` |
| STG views | entity name, no prefix, typed columns | `RELIABILITY`, `AMI`, `SALES`, `NOAA_VA_EVENTS`, `EIA930_DOM_HOURLY` |
| MART | `DIM_` dimension, `FCT_` fact, `V_` view, plain noun for a derived table | `DIM_UTILITY`, `FCT_RELIABILITY`, `V_TREND`, `V_GROUP_INDEX`, `STORM_INDEX`, `DOM_LOAD_ANNUAL` |
| Roles, users | `<PURPOSE>_READER`, `<TOOL>_SVC` | `BI_READER`, `POWERBI_SVC` |

## Columns

snake_case.

| Suffix or word | Meaning | Examples |
|---|---|---|
| `_ex_med` | excluding major event days | `saidi_ex_med` |
| `_all` | all events | `saidi_all` |
| `_py` | prior year | `saidi_ex_med_py` |
| `_5yr`, `_3yr` | rolling or period average | `saidi_ex_med_5yr` |
| `cust_minutes_*`, `cust_interruptions_*` | additive numerators (SAIDI x customers, SAIFI x customers) | |
| `_mw`, `_twh`, `_kv`, `_kt` | unit | `peak_mw`, `energy_twh`, `max_kv`, `max_gust_kt` |
| `_pct` | percentage, already multiplied by 100 | `growth_pct` |
| `_share` | fraction between 0 and 1 | `storm_share`, `ami_share` |
| `_days` | count of county-days | `storm_county_days` |
| `year` | data year, four digits | |
| `*_key` | surrogate key built from IDs | `utility_key = utility_id \|\| '\|' \|\| state` |
| `*_fips` | five-digit county FIPS as text with leading zeros | `county_id_fips` |

`customers` is a count of customers. `saidi_*` is minutes per customer. `adjusted` refers to the weather fit only. The major-event exclusion is always `_ex_med`.

## Tests and analysis queries

- Tests: `T<n>`, numbered across files (T1 to T6 in 04, T7 to T9 in 05, T10 to T12 in 06). The expected result is stated in the comment above each test.
- Analysis queries: `Q<n>`, with a letter suffix for variants (`Q3b`).

## Documentation

- `NN_<topic>.md`, numbered in reading order.
- Each document opens with one sentence stating its scope.
- Figures quoted in documentation name the table and query they come from.

## Data files

- Input files keep the publisher's file name (`Reliability_2025_States.csv`, `EIA930_SUBREGION_2025_Jan_Jun.csv`).
- Output files are snake_case nouns (`storm_index.csv`, `dom_annual.csv`).
- Files in `data/` are not edited by hand. Corrections are made in SQL.

## Power BI

| Item | Convention | Examples |
|---|---|---|
| Measures | metric name, Title Case, scope in words | `SAIDI ex MED`, `SAIDI 3yr ending 2025`, `CAIDI 5yr` |
| Helper measures | named for what they return | `Bar colour`, `SAIFI label`, `Hour colour` |
| Calculated columns | Title Case | `Display name`, `Short name`, `Region` |
| Columns from Snowflake | Snowflake names unchanged | `SAIDI_EX_MED` |
| Visual titles | sentence case, state the finding | "Outages per customer up 6% since 2019, most of it after 2023" |
| Visual subtitles | unit and source | "SAIFI ex MED, 2015 = 100. Dominion vs all Virginia co-ops. EIA-861" |
| Report tabs | `Summary`, `Scorecard`, `What moved`, `Weather`, `Fair comparison`, `Growth`, `Data notes` | |
| Colours | `#0A66C2` subject of the chart, `#B8BCC2` context, `#6B7280` second context, `#E8B117` third category, `#1F2A44` dark accent | |

## Git

- Branch `main`.
- Commit messages: imperative mood, under 72 characters, one logical change per commit.
- Tags per presented version: `v1.0`, `v1.1`.
- `CHANGELOG.md` entry per load: date, version, row counts, tests whose result changed.
- Not committed: raw downloads over 25 MB, `.pbix` files, credentials.
