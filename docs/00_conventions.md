# 00. Conventions

The rules every name in this repository follows. If a name does not fit, the name is wrong, not the rule.

## Repository and folders

- Repository: `dominion-reliability-review`. Kebab-case, a noun phrase, what it is rather than how it was built.
- Folders: lowercase, one word, named for the role of the contents: `sql/` `docs/` `scripts/` `data/` `powerbi/`. Under `data/`: `input/` as loaded, `reference/` lookups, `output/` derived, `raw/` large downloads (ignored by git).
- Never `misc`, `old`, `new`, `final`, `v2`.

## SQL files

`NN_<what>.sql`, two-digit run order, snake_case. One file is one layer (01 raw and staging, 02 mart, 04 tests) or one source (05 NOAA, 06 EIA-930), never a mix. Analysis queries live in 03 or at the foot of a source file. Grants are their own file, last. Every file states the row counts or results to expect in comments beside the statement that produces them.

## Snowflake objects (upper case, as Snowflake displays them)

| Object | Pattern | Examples |
|---|---|---|
| Database, schemas | `RELIABILITY`; `RAW`, `STG`, `MART` | |
| File formats | `FF_<SOURCE>_CSV` | `FF_EIA_CSV`, `FF_NOAA_CSV`, `FF_EIA930_CSV` |
| Stages | `<SOURCE>_STAGE` | `EIA_STAGE`, `PUDL_STAGE`, `NOAA_STAGE`, `EIA930_STAGE` |
| RAW tables | `<SOURCE>_<TABLE>[_<YEAR>]`, one per source file, every column VARCHAR | `EIA861_RELIABILITY_2025`, `PUDL_SALES`, `NOAA_STORM_EVENTS`, `EIA930_SUBREGION` |
| STG views | the entity, no prefix, typed | `RELIABILITY`, `AMI`, `SALES`, `NOAA_VA_EVENTS`, `EIA930_DOM_HOURLY` |
| MART | `DIM_` dimension, `FCT_` fact, `V_` view, plain noun for a derived table | `DIM_UTILITY`, `FCT_RELIABILITY`, `V_TREND`, `V_GROUP_INDEX`, `STORM_INDEX`, `DOM_LOAD_ANNUAL` |
| Roles, users | `<PURPOSE>_READER`, `<TOOL>_SVC` | `BI_READER`, `POWERBI_SVC` |

## Columns (snake_case)

| Suffix or word | Meaning | Examples |
|---|---|---|
| `_ex_med` | excluding major event days | `saidi_ex_med` |
| `_all` | all events | `saidi_all` |
| `_py` | prior year | `saidi_ex_med_py` |
| `_5yr`, `_3yr` | rolling or period average | `saidi_ex_med_5yr` |
| `cust_minutes_*`, `cust_interruptions_*` | additive numerators (SAIDI x customers, SAIFI x customers) | |
| `_mw`, `_twh`, `_kv`, `_kt` | unit | `peak_mw`, `energy_twh`, `max_kv`, `max_gust_kt` |
| `_pct` | a percentage already multiplied by 100 | `growth_pct` |
| `_share` | a fraction 0 to 1 | `storm_share`, `ami_share` |
| `_days` | count of county-days | `storm_county_days` |
| `year` | data year, always a 4-digit number | |
| `*_key` | surrogate key built from IDs, never names | `utility_key = utility_id \|\| '\|' \|\| state` |
| `*_fips` | 5-digit county FIPS as text with leading zeros | `county_id_fips` |

`customers` is always a count of customers. `saidi_*` is always minutes per customer. "Adjusted" is reserved for the weather fit; the storm exclusion is always `_ex_med`.

## Tests and questions

`T<n>` for tests, numbered across files (T1 to T6 in 04, T7 to T9 in 05, T10 to T12 in 06). `Q<n>` for analysis queries, with a letter for variants (`Q3b`). Every test states its expected result in the comment above it.

## Documentation

`NN_<topic>.md` in reading order. Headings are nouns or questions. Each doc opens with one sentence saying what it is for. Numbers quoted in docs come from a named table and query.

## Data files

Inputs keep the publisher's file name so provenance is visible at a glance (`Reliability_2025_States.csv`, `EIA930_SUBREGION_2025_Jan_Jun.csv`). Outputs are snake_case nouns (`storm_index.csv`, `dom_annual.csv`). Nothing in `data/` is ever edited by hand.

## Power BI

| Thing | Convention | Examples |
|---|---|---|
| Measures | metric name, Title Case, scope in words | `SAIDI ex MED`, `SAIDI 3yr ending 2025`, `CAIDI 5yr` |
| Helper measures | end in what they return | `Bar colour`, `SAIFI label`, `Hour colour` |
| Calculated columns | Title Case | `Display name`, `Short name`, `Region` |
| Columns from Snowflake | left exactly as Snowflake names them | `SAIDI_EX_MED` |
| Visual titles | sentence case, state the finding | "Outages per customer up 6% since 2019, most of it after 2023" |
| Visual subtitles | unit and source, no restating the legend | "SAIFI ex MED, 2015 = 100. Dominion vs all Virginia co-ops. EIA-861" |
| Report tabs | `Summary`, `Scorecard`, `What moved`, `Weather`, `Fair comparison`, `Growth`, `Data notes` | |
| Colours | `#0A66C2` the thing being judged, `#B8BCC2` context, `#6B7280` second context, `#E8B117` third category, `#1F2A44` dark accent | |

## Git

- Branch `main`. Feature branches only if more than one person works on it.
- Commit messages: imperative mood, under 72 characters, one logical change per commit. `Add COPY GRANTS to every mart object`, `Fix LN(0) guard in V_TREND`, never `updates` or `wip`.
- Tags per presented version: `v1.0`, `v1.1`.
- `CHANGELOG.md` entry per load: date, version, row counts, tests whose result moved.
- Never committed: raw downloads over 25 MB, `.pbix`, anything with a password or key.
