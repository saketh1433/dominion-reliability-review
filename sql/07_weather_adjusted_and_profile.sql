-- =====================================================================
-- DOMINION RELIABILITY MART  |  07: weather-adjusted reliability and the
-- hour-of-day load profile. Run after 05 and 06.
-- =====================================================================
USE WAREHOUSE SNOWFLAKE_LEARNING_WH;

-- ---------- 1. Storm index joined to Dominion's reliability row ----------
-- One row per year. Source for the Weather page scatter and the fit below.
CREATE OR REPLACE VIEW RELIABILITY.MART.V_STORM_VS_SAIDI COPY GRANTS AS
SELECT s.year, s.storm_county_days, s.wind_days, s.winter_days, s.tropical_days, s.severe_gust_days,
       f.saidi_ex_med, f.saifi_ex_med, f.storm_saidi
FROM RELIABILITY.MART.STORM_INDEX s
JOIN RELIABILITY.MART.FCT_RELIABILITY f
  ON f.year = s.year AND f.utility_key = '19876|VA';

-- ---------- 2. Weather-adjusted SAIDI ----------
-- Fit SAIDI ex MED on storm county-days over 2015 to 2024 (decision D6:
-- 2013-14 precede the 2015 counting change and 2025 is held out so that its
-- prediction is out of sample). Weather-adjusted = actual - predicted +
-- period mean.
CREATE OR REPLACE TABLE RELIABILITY.MART.SAIDI_WEATHER_ADJUSTED COPY GRANTS AS
WITH fit AS (
  SELECT REGR_SLOPE(saidi_ex_med, storm_county_days)     AS slope,
         REGR_INTERCEPT(saidi_ex_med, storm_county_days) AS intercept,
         AVG(saidi_ex_med)                               AS mean_saidi
  FROM RELIABILITY.MART.V_STORM_VS_SAIDI
  WHERE year BETWEEN 2015 AND 2024
)
SELECT v.year, v.storm_county_days, v.saidi_ex_med,
       ROUND(f.intercept + f.slope * v.storm_county_days, 1)                                   AS predicted_from_weather,
       ROUND(v.saidi_ex_med - (f.intercept + f.slope * v.storm_county_days) + f.mean_saidi, 1) AS weather_adjusted_saidi,
       ROUND(f.slope, 4)                                                                       AS fit_slope,
       ROUND(f.intercept, 1)                                                                   AS fit_intercept,
       ROUND(f.mean_saidi, 1)                                                                  AS fit_mean
FROM RELIABILITY.MART.V_STORM_VS_SAIDI v CROSS JOIN fit f
WHERE v.year >= 2015;

-- Check: expected 11 rows. 2019 weather_adjusted 135.8, 2025 133.1,
-- predicted_from_weather for 2025 145.3, slope 0.0514, intercept 104.4
SELECT * FROM RELIABILITY.MART.SAIDI_WEATHER_ADJUSTED ORDER BY year;

-- ---------- 3. Hour-of-day load profile, 2019 vs 2025 ----------
-- Average demand in each hour of the day, 2019 vs 2025.
CREATE OR REPLACE TABLE RELIABILITY.MART.DOM_LOAD_PROFILE COPY GRANTS AS
SELECT hour_no,
       ROUND(AVG(CASE WHEN YEAR(data_date) = 2019 THEN demand_mw END)) AS avg_mw_2019,
       ROUND(AVG(CASE WHEN YEAR(data_date) = 2025 THEN demand_mw END)) AS avg_mw_2025,
       ROUND(100 * (AVG(CASE WHEN YEAR(data_date) = 2025 THEN demand_mw END)
                  / AVG(CASE WHEN YEAR(data_date) = 2019 THEN demand_mw END) - 1), 1) AS growth_pct
FROM RELIABILITY.STG.EIA930_DOM_HOURLY
WHERE hour_no BETWEEN 1 AND 24
GROUP BY 1;

-- Check: expected 24 rows. Hour 4 growth 41.0, hour 16 growth 27.1
SELECT * FROM RELIABILITY.MART.DOM_LOAD_PROFILE ORDER BY hour_no;

-- ---------- 4. Analysis ----------
-- Q10. Trend in the weather-adjusted series. Expect a slope under one
--      minute a year.
SELECT ROUND(REGR_SLOPE(weather_adjusted_saidi, year), 2) AS minutes_per_year_2015_2025,
       ROUND(AVG(CASE WHEN year BETWEEN 2015 AND 2018 THEN weather_adjusted_saidi END), 1) AS avg_2015_2018,
       ROUND(AVG(CASE WHEN year BETWEEN 2019 AND 2022 THEN weather_adjusted_saidi END), 1) AS avg_2019_2022,
       ROUND(AVG(CASE WHEN year BETWEEN 2023 AND 2025 THEN weather_adjusted_saidi END), 1) AS avg_2023_2025
FROM RELIABILITY.MART.SAIDI_WEATHER_ADJUSTED;

-- Q11. Daily load factor: ratio of each day's lowest hour to its highest,
--      averaged over the year. Expect 0.69 in 2019 and 0.76 in 2025.
WITH d AS (
  SELECT YEAR(data_date) AS year, data_date, MIN(demand_mw) AS lo, MAX(demand_mw) AS hi
  FROM RELIABILITY.STG.EIA930_DOM_HOURLY
  WHERE demand_mw IS NOT NULL
  GROUP BY 1, 2
)
SELECT year, ROUND(AVG(lo)) AS avg_daily_min_mw, ROUND(AVG(hi)) AS avg_daily_max_mw, ROUND(AVG(lo / hi), 3) AS avg_min_over_max
FROM d WHERE year BETWEEN 2019 AND 2025
GROUP BY 1 ORDER BY 1;
