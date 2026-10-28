-- =====================================================================
-- DOMINION RELIABILITY MART  |  05: NOAA storm events, the independent witness
-- Adds three raw tables, two staging views, one mart table, two tests and
-- one analysis query. Run after 01 to 04.
-- =====================================================================

-- ---------- 0. File format and stage (Snowflake only) ----------
-- NOAA's yearly files are gzip CSV. Snowflake detects the gzip itself.
CREATE OR REPLACE FILE FORMAT RELIABILITY.RAW.FF_NOAA_CSV
  TYPE = CSV
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  NULL_IF = ('')
  EMPTY_FIELD_AS_NULL = TRUE;

CREATE STAGE IF NOT EXISTS RELIABILITY.RAW.NOAA_STAGE FILE_FORMAT = RELIABILITY.RAW.FF_NOAA_CSV;
-- Upload the 13 StormEvents_details-ftp_v1.0_d20YY_*.csv.gz files, the
-- zone_county_correlation.csv and Service_Territory_2025_Counties_States.csv
-- into NOAA_STAGE through Snowsight.

-- ---------- 1. Raw tables, all text ----------
CREATE OR REPLACE TABLE RELIABILITY.RAW.NOAA_STORM_EVENTS (
  begin_yearmonth VARCHAR, begin_day VARCHAR, begin_time VARCHAR,
  end_yearmonth VARCHAR, end_day VARCHAR, end_time VARCHAR,
  episode_id VARCHAR, event_id VARCHAR, state VARCHAR, state_fips VARCHAR,
  year VARCHAR, month_name VARCHAR, event_type VARCHAR, cz_type VARCHAR,
  cz_fips VARCHAR, cz_name VARCHAR, wfo VARCHAR, begin_date_time VARCHAR,
  cz_timezone VARCHAR, end_date_time VARCHAR, injuries_direct VARCHAR,
  injuries_indirect VARCHAR, deaths_direct VARCHAR, deaths_indirect VARCHAR,
  damage_property VARCHAR, damage_crops VARCHAR, source VARCHAR, magnitude VARCHAR,
  magnitude_type VARCHAR, flood_cause VARCHAR, category VARCHAR, tor_f_scale VARCHAR,
  tor_length VARCHAR, tor_width VARCHAR, tor_other_wfo VARCHAR, tor_other_cz_state VARCHAR,
  tor_other_cz_fips VARCHAR, tor_other_cz_name VARCHAR, begin_range VARCHAR,
  begin_azimuth VARCHAR, begin_location VARCHAR, end_range VARCHAR, end_azimuth VARCHAR,
  end_location VARCHAR, begin_lat VARCHAR, begin_lon VARCHAR, end_lat VARCHAR, end_lon VARCHAR,
  episode_narrative VARCHAR, event_narrative VARCHAR, data_source VARCHAR
);

-- NOAA's forecast-zone to county lookup
CREATE OR REPLACE TABLE RELIABILITY.RAW.NOAA_ZONE_COUNTY (
  state VARCHAR, cwa VARCHAR, zone_name VARCHAR, state_zone VARCHAR, county_name VARCHAR,
  fips VARCHAR, time_zone VARCHAR, fe_area VARCHAR, lat VARCHAR, lon VARCHAR, zone VARCHAR, nws_date VARCHAR
);

-- EIA-861 Service Territory: which counties each utility serves
CREATE OR REPLACE TABLE RELIABILITY.RAW.EIA861_SERVICE_TERRITORY_2025 (
  data_year VARCHAR, utility_number VARCHAR, utility_name VARCHAR, short_form VARCHAR, state VARCHAR, county VARCHAR
);

-- One COPY loads all 13 years because of the PATTERN. Upload the 13 .csv.gz
-- files and the two CSVs into NOAA_STAGE through Snowsight first.
COPY INTO RELIABILITY.RAW.NOAA_STORM_EVENTS FROM @RELIABILITY.RAW.NOAA_STAGE
  PATTERN = '.*StormEvents_details-ftp_v1.0_d20[0-9]{2}_c[0-9]{8}\.csv\.gz';
COPY INTO RELIABILITY.RAW.NOAA_ZONE_COUNTY FROM @RELIABILITY.RAW.NOAA_STAGE/zone_county_correlation.csv;
COPY INTO RELIABILITY.RAW.EIA861_SERVICE_TERRITORY_2025 FROM @RELIABILITY.RAW.NOAA_STAGE/Service_Territory_2025_Counties_States.csv;

-- Check: expected 831288, 7087, 11803
SELECT 'noaa' AS t, COUNT(*) AS n FROM RELIABILITY.RAW.NOAA_STORM_EVENTS
UNION ALL SELECT 'zones',     COUNT(*) FROM RELIABILITY.RAW.NOAA_ZONE_COUNTY
UNION ALL SELECT 'territory', COUNT(*) FROM RELIABILITY.RAW.EIA861_SERVICE_TERRITORY_2025;

-- ---------- 2. Staging ----------
-- Dominion Energy Virginia's counties as 5-digit FIPS codes.
-- EIA writes "Alexandria City", NOAA writes "City of Alexandria", so try both
-- spellings. Two counties really are called James City and Charles City.
CREATE OR REPLACE VIEW RELIABILITY.STG.DOMINION_VA_COUNTIES AS
WITH eia AS (
  SELECT county,
         CASE WHEN county LIKE '% City' THEN 'City of ' || LEFT(county, LENGTH(county) - 5) ELSE county END AS noaa_name
  FROM RELIABILITY.RAW.EIA861_SERVICE_TERRITORY_2025
  WHERE TRY_TO_NUMBER(utility_number) = 19876 AND state = 'VA'
),
lookup AS (
  SELECT DISTINCT county_name, LPAD(fips, 5, '0') AS county_id_fips
  FROM RELIABILITY.RAW.NOAA_ZONE_COUNTY
  WHERE state = 'VA' AND fips <> '9999'
)
SELECT e.county AS eia_county, MIN(l.county_id_fips) AS county_id_fips
FROM eia e
LEFT JOIN lookup l ON LOWER(l.county_name) IN (LOWER(e.county), LOWER(e.noaa_name))
GROUP BY e.county;

-- One row per Virginia storm event per county it touched.
-- County events carry the county code directly. Zone events are spread over
-- the counties in that forecast zone through NOAA's own lookup.
CREATE OR REPLACE VIEW RELIABILITY.STG.NOAA_VA_EVENTS AS
SELECT
  TRY_TO_NUMBER(e.event_id)            AS event_id,
  TRY_TO_NUMBER(e.episode_id)          AS episode_id,
  TRY_TO_NUMBER(e.year)                AS year,
  TRY_TO_NUMBER(e.begin_yearmonth)     AS begin_yearmonth,
  TRY_TO_NUMBER(e.begin_day)           AS begin_day,
  e.event_type,
  e.cz_type,
  CASE WHEN e.cz_type = 'C' THEN '51' || LPAD(e.cz_fips, 3, '0')
       ELSE COALESCE(LPAD(z.fips, 5, '0'), n.county_id_fips) END AS county_id_fips,
  TRY_TO_NUMBER(e.magnitude, 8, 2)     AS magnitude,
  CASE
    WHEN e.event_type IN ('Thunderstorm Wind','High Wind','Strong Wind','Tornado') THEN 'wind'
    WHEN e.event_type IN ('Ice Storm','Winter Storm','Heavy Snow','Blizzard','Sleet') THEN 'winter'
    WHEN e.event_type IN ('Hurricane','Hurricane (Typhoon)','Tropical Storm','Tropical Depression') THEN 'tropical'
    ELSE 'other'
  END AS line_risk
FROM RELIABILITY.RAW.NOAA_STORM_EVENTS e
LEFT JOIN RELIABILITY.RAW.NOAA_ZONE_COUNTY z
  ON e.cz_type = 'Z' AND z.state = 'VA' AND z.fips <> '9999'
 AND TRY_TO_NUMBER(z.zone) = TRY_TO_NUMBER(e.cz_fips)
-- second pass: zones renumbered after the lookup was built carry the county
-- name in cz_name, so match on the name when the zone number is unknown
LEFT JOIN (
  SELECT DISTINCT UPPER(REPLACE(county_name, 'City of ', '')) AS county_name, LPAD(fips, 5, '0') AS county_id_fips
  FROM RELIABILITY.RAW.NOAA_ZONE_COUNTY WHERE state = 'VA' AND fips <> '9999'
) n ON e.cz_type = 'Z' AND z.fips IS NULL AND n.county_name = UPPER(e.cz_name)
WHERE e.state = 'VIRGINIA';

-- ---------- 3. Mart: the storm index, one row per year ----------
-- A "storm county-day" is one county with at least one line-risk event on one
-- date. Counting county-days rather than events stops one squall line that
-- produced 40 wind reports in one county from counting 40 times.
CREATE OR REPLACE TABLE RELIABILITY.MART.STORM_INDEX COPY GRANTS AS
WITH days AS (
  SELECT year, county_id_fips, begin_yearmonth, begin_day,
         MAX(CASE WHEN line_risk = 'wind'     THEN 1 ELSE 0 END) AS wind,
         MAX(CASE WHEN line_risk = 'winter'   THEN 1 ELSE 0 END) AS winter,
         MAX(CASE WHEN line_risk = 'tropical' THEN 1 ELSE 0 END) AS tropical,
         MAX(CASE WHEN event_type = 'Thunderstorm Wind' THEN magnitude END) AS max_gust_kt
  FROM RELIABILITY.STG.NOAA_VA_EVENTS
  WHERE county_id_fips IN (SELECT county_id_fips FROM RELIABILITY.STG.DOMINION_VA_COUNTIES WHERE county_id_fips IS NOT NULL)
    AND line_risk <> 'other'
  GROUP BY 1, 2, 3, 4
)
SELECT year,
       COUNT(*)                                          AS storm_county_days,
       SUM(wind)                                         AS wind_days,
       SUM(winter)                                       AS winter_days,
       SUM(tropical)                                     AS tropical_days,
       SUM(CASE WHEN max_gust_kt >= 60 THEN 1 ELSE 0 END) AS severe_gust_days
FROM days
GROUP BY year
ORDER BY year;

-- ---------- 4. Tests ----------
-- T7. Every Dominion county found a FIPS code (expected 0 rows)
SELECT * FROM RELIABILITY.STG.DOMINION_VA_COUNTIES WHERE county_id_fips IS NULL;

-- T8. The 2025 file is a full year (expected one row: 202512)
SELECT MAX(begin_yearmonth) AS last_month FROM RELIABILITY.STG.NOAA_VA_EVENTS WHERE year = 2025;

-- T9. Zone events that found no county even after the name pass (expected 0)
SELECT COUNT(*) AS unmapped_zone_rows FROM RELIABILITY.STG.NOAA_VA_EVENTS WHERE county_id_fips IS NULL;

-- ---------- 5. Analysis ----------
-- Q6. Does NOAA's independent storm count move with Dominion's day-to-day minutes?
WITH j AS (
  SELECT s.year, s.storm_county_days, s.wind_days, s.winter_days,
         f.saidi_ex_med, f.saifi_ex_med, f.storm_saidi
  FROM RELIABILITY.MART.STORM_INDEX s
  JOIN RELIABILITY.MART.FCT_RELIABILITY f ON f.year = s.year AND f.utility_key = '19876|VA'
)
SELECT * FROM j ORDER BY year;

-- Q6b. The headline: correlations, and what 2025's weather alone would predict
WITH j AS (
  SELECT s.year, s.storm_county_days, s.wind_days, f.saidi_ex_med, f.saifi_ex_med, f.storm_saidi
  FROM RELIABILITY.MART.STORM_INDEX s
  JOIN RELIABILITY.MART.FCT_RELIABILITY f ON f.year = s.year AND f.utility_key = '19876|VA'
),
fit AS (
  SELECT REGR_SLOPE(saidi_ex_med, storm_county_days)     AS slope,
         REGR_INTERCEPT(saidi_ex_med, storm_county_days) AS intercept,
         CORR(saidi_ex_med, storm_county_days)           AS corr_daytoday,
         CORR(storm_saidi,  storm_county_days)           AS corr_major_storm,
         CORR(saifi_ex_med, storm_county_days)           AS corr_frequency
  FROM j WHERE year BETWEEN 2015 AND 2024
)
SELECT ROUND(corr_daytoday, 2)    AS corr_with_daytoday_minutes,
       ROUND(corr_frequency, 2)   AS corr_with_frequency,
       ROUND(corr_major_storm, 2) AS corr_with_major_storm_minutes,
       ROUND(intercept + slope * (SELECT storm_county_days FROM j WHERE year = 2025), 1) AS predicted_2025_daytoday_saidi,
       (SELECT saidi_ex_med FROM j WHERE year = 2025) AS actual_2025_daytoday_saidi
FROM fit;
