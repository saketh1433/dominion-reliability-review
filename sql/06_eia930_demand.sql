-- =====================================================================
-- DOMINION RELIABILITY MART  |  06: EIA-930 hourly demand, the DOM zone
-- Adds one raw table, one staging view, two mart tables, three tests and
-- four analysis queries. Run after 01 to 05.
--
-- What this is: every hour since July 2018, how much electricity the PJM
-- "DOM" zone used. DOM is Dominion's transmission zone (Virginia and
-- north-east North Carolina, plus the co-ops that take power through it).
-- It is not outage data. It answers one question the reliability data
-- cannot: how fast is the load growing, and in what shape.
-- =====================================================================

USE WAREHOUSE SNOWFLAKE_LEARNING_WH;

-- ---------- 0. File format and stage (Snowflake only) ----------
CREATE OR REPLACE FILE FORMAT RELIABILITY.RAW.FF_EIA930_CSV
  TYPE = CSV
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  NULL_IF = ('')
  EMPTY_FIELD_AS_NULL = TRUE;

CREATE STAGE IF NOT EXISTS RELIABILITY.RAW.EIA930_STAGE FILE_FORMAT = RELIABILITY.RAW.FF_EIA930_CSV;
-- Upload the 17 EIA930_SUBREGION_20YY_Jan_Jun.csv / Jul_Dec.csv files
-- (2018_Jul_Dec through 2026_Jul_Dec) into EIA930_STAGE through Snowsight.
-- 2018_Jan_Jun does not exist: subregion reporting starts 1 July 2018.
-- A 44 KB file by that name is the HTML error page EIA serves instead. Do not load it.
-- After the upload, confirm the files are there (expected 17 rows):
LIST @RELIABILITY.RAW.EIA930_STAGE;

-- ---------- 1. Raw table, all text ----------
CREATE OR REPLACE TABLE RELIABILITY.RAW.EIA930_SUBREGION (
  balancing_authority VARCHAR, data_date VARCHAR, hour_number VARCHAR,
  sub_region VARCHAR, demand_mw VARCHAR, local_time_end VARCHAR, utc_time_end VARCHAR
);

-- One COPY loads all 17 files because of the PATTERN.
COPY INTO RELIABILITY.RAW.EIA930_SUBREGION FROM @RELIABILITY.RAW.EIA930_STAGE
  PATTERN = '.*EIA930_SUBREGION_20[0-9]{2}_(Jan_Jun|Jul_Dec)\.csv';

-- Check: expected 6077232 in total, 72864 for PJM / DOM
SELECT 'all subregions' AS t, COUNT(*) AS n FROM RELIABILITY.RAW.EIA930_SUBREGION
UNION ALL
SELECT 'PJM DOM', COUNT(*) FROM RELIABILITY.RAW.EIA930_SUBREGION
WHERE balancing_authority = 'PJM' AND sub_region = 'DOM';

-- ---------- 2. Staging ----------
-- Only the DOM zone, typed. Two things happen here:
--   1. the hour is kept in UTC so the clock-change days (23 and 25 hours) do
--      not create duplicates;
--   2. demand above 60,000 MW is set to NULL. The whole of PJM peaks near
--      150,000 MW and DOM alone near 25,000, so a DOM hour above 60,000 is a
--      reporting error. There are two such rows, on 18 October 2021, at
--      1.5 billion and 1.0 billion MW. The reported value is kept in its own
--      column so the test below can show them.
CREATE OR REPLACE VIEW RELIABILITY.STG.EIA930_DOM_HOURLY AS
SELECT
  TRY_TO_DATE(data_date, 'MM/DD/YYYY')                              AS data_date,
  TRY_TO_NUMBER(hour_number)                                        AS hour_no,
  TRY_TO_TIMESTAMP_NTZ(utc_time_end,   'MM/DD/YYYY HH12:MI:SS AM')  AS utc_ts,
  TRY_TO_TIMESTAMP_NTZ(local_time_end, 'MM/DD/YYYY HH12:MI:SS AM')  AS local_ts,
  TRY_TO_NUMBER(REPLACE(demand_mw, ',', ''))                        AS demand_mw_reported,
  CASE WHEN TRY_TO_NUMBER(REPLACE(demand_mw, ',', '')) > 60000 THEN NULL
       ELSE TRY_TO_NUMBER(REPLACE(demand_mw, ',', '')) END          AS demand_mw
FROM RELIABILITY.RAW.EIA930_SUBREGION
WHERE balancing_authority = 'PJM' AND sub_region = 'DOM';

-- Check: expected 72864
SELECT COUNT(*) FROM RELIABILITY.STG.EIA930_DOM_HOURLY;

-- ---------- 3. Mart ----------
-- One row per year: the peak in each season, the floor, the middle and the energy.
-- Winter = Dec, Jan, Feb of the same calendar year. Summer = Jun, Jul, Aug.
CREATE OR REPLACE TABLE RELIABILITY.MART.DOM_LOAD_ANNUAL COPY GRANTS AS
SELECT
  YEAR(data_date)                                                   AS year,
  MAX(CASE WHEN MONTH(data_date) IN (12, 1, 2) THEN demand_mw END)  AS winter_peak_mw,
  MAX(CASE WHEN MONTH(data_date) IN (6, 7, 8)  THEN demand_mw END)  AS summer_peak_mw,
  MAX(demand_mw)                                                    AS peak_mw,
  MIN(demand_mw)                                                    AS floor_mw,
  ROUND(MEDIAN(demand_mw))                                          AS median_mw,
  ROUND(AVG(demand_mw))                                             AS avg_mw,
  ROUND(SUM(demand_mw) / 1e6, 2)                                    AS energy_twh,
  COUNT(demand_mw)                                                  AS hours_reported,
  COUNT(*) - COUNT(demand_mw)                                       AS hours_missing
FROM RELIABILITY.STG.EIA930_DOM_HOURLY
GROUP BY 1;

-- The 50 highest hours on record, ranked twice: as the record stood on
-- 31 December 2025 (the window Dominion's annual report describes) and as it
-- stands today.
CREATE OR REPLACE TABLE RELIABILITY.MART.DOM_TOP50_HOURS COPY GRANTS AS
WITH ranked AS (
  SELECT data_date, hour_no, utc_ts, demand_mw,
         ROW_NUMBER() OVER (ORDER BY demand_mw DESC) AS rank_today,
         -- hours from 2026 sort to the bottom, so the top 50 here is the top 50 to end-2025
         ROW_NUMBER() OVER (ORDER BY CASE WHEN data_date < '2026-01-01' THEN demand_mw END DESC NULLS LAST) AS rank_end_2025_raw
  FROM RELIABILITY.STG.EIA930_DOM_HOURLY
  WHERE demand_mw IS NOT NULL
)
SELECT YEAR(data_date) AS year, data_date, hour_no, utc_ts, demand_mw, rank_today,
       CASE WHEN data_date < '2026-01-01' THEN rank_end_2025_raw END AS rank_end_2025
FROM ranked
WHERE rank_today <= 50 OR (data_date < '2026-01-01' AND rank_end_2025_raw <= 50);

-- Check: expected 9 rows, 2018 to 2026
SELECT * FROM RELIABILITY.MART.DOM_LOAD_ANNUAL ORDER BY year;

-- ---------- 4. Tests ----------
-- T10. Impossible demand values (expected 2 rows, both 18 Oct 2021). These are
--      what the staging view sets to NULL. If more appear after a refresh, look.
SELECT data_date, hour_no, demand_mw_reported
FROM RELIABILITY.STG.EIA930_DOM_HOURLY
WHERE demand_mw_reported > 60000;

-- T11. No hour appears twice (expected 0 rows). UTC makes this true even on
--      the March and November clock-change days.
SELECT utc_ts, COUNT(*) FROM RELIABILITY.STG.EIA930_DOM_HOURLY GROUP BY 1 HAVING COUNT(*) > 1;

-- T12. Every full year has at least 8,700 reported hours (expected 0 rows).
--      2018 starts in July and 2026 is not finished, so they are excluded.
SELECT year, hours_reported FROM RELIABILITY.MART.DOM_LOAD_ANNUAL
WHERE year BETWEEN 2019 AND 2025 AND hours_reported < 8700;

-- ---------- 5. Analysis ----------
-- Q7. The annual report says "38 of the 50 highest peak loads in DOM Zone
--     history have occurred since 1 January 2025". EIA's record starts in
--     July 2018, so older summers are not in it, and the count comes out
--     higher: 47 of 50 in 2025, the other 3 in 2024.
SELECT year, COUNT(*) AS hours_in_top50, MAX(demand_mw) AS highest_mw
FROM RELIABILITY.MART.DOM_TOP50_HOURS
WHERE rank_end_2025 <= 50
GROUP BY 1 ORDER BY 1;

-- Q7b. The same count as the record stands today. Expect 46 of 50 in 2026.
SELECT year, COUNT(*) AS hours_in_top50, MAX(demand_mw) AS highest_mw
FROM RELIABILITY.MART.DOM_TOP50_HOURS
WHERE rank_today <= 50
GROUP BY 1 ORDER BY 1;

-- Q8. Winter or summer? The report says Dominion now peaks in winter.
--     2022 and 2025 were winter-peaking (Dec 2022 Winter Storm Elliott,
--     Jan 2025 cold snap). 2026 is a tie: 25,413 on 9 Feb at 8am against
--     25,384 on 3 Jul at 7pm.
SELECT year, winter_peak_mw, summer_peak_mw,
       CASE WHEN winter_peak_mw > summer_peak_mw THEN 'winter' ELSE 'summer' END AS peak_season
FROM RELIABILITY.MART.DOM_LOAD_ANNUAL ORDER BY 1;

-- Q9. The shape of the growth, 2019 to 2025.
--     Data centres run flat all day and all night, so they lift the lowest
--     hour of the year more than the highest. Expect: peak +26%, floor +52%,
--     median +32%, energy +32%.
SELECT
  ROUND(100 * (b.peak_mw   / a.peak_mw   - 1), 1) AS peak_growth_pct,
  ROUND(100 * (b.floor_mw  / a.floor_mw  - 1), 1) AS floor_growth_pct,
  ROUND(100 * (b.median_mw / a.median_mw - 1), 1) AS median_growth_pct,
  ROUND(100 * (b.energy_twh / a.energy_twh - 1), 1) AS energy_growth_pct
FROM RELIABILITY.MART.DOM_LOAD_ANNUAL a
JOIN RELIABILITY.MART.DOM_LOAD_ANNUAL b ON a.year = 2019 AND b.year = 2025;

-- ---------- 6. Power BI ----------
-- BI_READER has SELECT on future tables in MART, so DOM_LOAD_ANNUAL and
-- DOM_TOP50_HOURS appear in Power BI on the next refresh. They feed the
-- Growth page: the top-50 card, the winter/summer columns and the growth cards.
