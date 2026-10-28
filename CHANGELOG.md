# Changelog

Every load and every definition change, with the row counts and any test whose result moved.

## 2026-10-28  v1.1  Transformation walkthrough and source links

- Added `docs/08_transformations.md`: the chain from raw cell to dashboard number, with five worked examples using real rows.
- Added direct download links, documentation links and licence links for every source to `docs/01_sources.md`.
- `V_GROUP_INDEX`: denominators now count only the customers of utilities that reported the numerator (P18). Co-op SAIFI 2025 level 1.849 -> 1.887. Co-op index 2025 unchanged at 137.4. No other group affected.
- `00_look_first.sql` query G updated to the matched denominator (expected 2.439 vs 1.887, 10 filed, 9 with SAIFI).

## 2026-10-27  v1.0  First complete build

- RAW loaded: EIA-861 2025 977, PUDL reliability 24,358, PUDL AMI 127,720, PUDL sales 198,770, NOAA events 831,288, NOAA zone lookup 7,087, EIA service territory 11,803, EIA-930 subregion 6,077,232 (PJM/DOM 72,864).
- MART: FCT_RELIABILITY 13,095 rows, 2013 to 2025. STORM_INDEX 13 rows. DOM_LOAD_ANNUAL 9 rows. DOM_TOP50_HOURS 96 rows. SAIDI_WEATHER_ADJUSTED 11 rows. DOM_LOAD_PROFILE 24 rows.
- Tests: T1 0, T2 0, T3 4 (known, EIA source), T4 0, T5 13 (informational), T6 0, T7 0, T8 202512, T9 0, T10 2 (known, 18 Oct 2021), T11 0, T12 0.
- Added 06 (EIA-930) and 07 (weather adjustment, hour-of-day profile) after the first NOAA build.
- Added FUTURE grants to BI_READER after CREATE OR REPLACE dropped the report's access.
- Fixed: LN(0) error in V_TREND for utilities reporting zero (NULLIF guard). James City and Charles City county matching. 140 renumbered NOAA zones matched on name.

## 2026-10-20  v0.2  NOAA storm index

- First STORM_INDEX. Correlation with SAIDI ex MED 0.70 over 2015 to 2024.

## 2026-10-13  v0.1  Reliability mart

- RAW, STG, MART for EIA-861 and PUDL. Six tests. Scorecard ties to the annual report (133.0, 130.2).
