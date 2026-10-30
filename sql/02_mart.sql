-- =====================================================================
-- DOMINION RELIABILITY MART  |  02: mart tables
-- =====================================================================

-- Utility dimension with peer groups
CREATE OR REPLACE TABLE RELIABILITY.MART.DIM_UTILITY COPY GRANTS AS
SELECT DISTINCT
  utility_id, state,
  utility_id || '|' || state AS utility_key,
  FIRST_VALUE(utility_name) OVER (PARTITION BY utility_id, state ORDER BY year DESC) AS utility_name,
  FIRST_VALUE(entity_type)  OVER (PARTITION BY utility_id, state ORDER BY year DESC) AS entity_type,
  CASE
    WHEN utility_id = 19876 AND state = 'VA' THEN 'Dominion Energy Virginia'
    WHEN state = 'VA' AND entity_type = 'Cooperative' THEN 'Virginia co-op'
    WHEN utility_id = 733 AND state = 'VA' THEN 'Appalachian Power (VA)'
    WHEN (utility_id, state) IN ((5416,'NC'),(3046,'NC'),(7140,'GA'),(195,'AL'),(17539,'SC')) THEN 'Southeast IOU peer'
    WHEN (utility_id, state) IN ((1167,'MD'),(15270,'MD'),(14940,'PA'),(14715,'PA')) THEN 'Mid-Atlantic IOU peer'
    WHEN (utility_id, state) IN ((6452,'FL'),(6455,'FL')) THEN 'Florida IOU peer'
    ELSE 'Other'
  END AS peer_group
FROM RELIABILITY.STG.RELIABILITY;

-- Reliability fact. Stores the additive numerators used for aggregation:
-- SAIDI = customer-minutes / customers.
CREATE OR REPLACE TABLE RELIABILITY.MART.FCT_RELIABILITY COPY GRANTS AS
SELECT
  utility_id || '|' || state AS utility_key,
  utility_id, state, year, standard, source,
  customers,
  saidi_all, saifi_all, caidi_all,
  saidi_ex_med, saifi_ex_med, caidi_ex_med,
  -- Legacy column names: these are *major-event-day exclusion differences*
  -- in the EIA filing, not measured NOAA storm-caused outage minutes.
  saidi_all - saidi_ex_med                       AS storm_saidi,
  saifi_all - saifi_ex_med                       AS storm_saifi,
  saidi_all * customers                          AS cust_minutes_all,
  saidi_ex_med * customers                       AS cust_minutes_ex_med,
  saifi_all * customers                          AS cust_interruptions_all,
  saifi_ex_med * customers                       AS cust_interruptions_ex_med,
  max_kv, auto_recorded, momentary_def, inactive_included
FROM RELIABILITY.STG.RELIABILITY;

-- Year-on-year and rolling views for one utility-state
CREATE OR REPLACE VIEW RELIABILITY.MART.V_TREND COPY GRANTS AS
SELECT
  f.utility_key, d.utility_name, d.peer_group, f.year, f.standard,
  f.saidi_ex_med, f.saifi_ex_med, f.caidi_ex_med, f.saidi_all, f.saifi_all, f.storm_saidi, f.storm_saifi,
  f.storm_saidi / NULLIF(f.saidi_all,0)                                           AS storm_share,
  LAG(f.saidi_ex_med) OVER (PARTITION BY f.utility_key ORDER BY f.year)          AS saidi_ex_med_py,
  LAG(f.saifi_ex_med) OVER (PARTITION BY f.utility_key ORDER BY f.year)          AS saifi_ex_med_py,
  LAG(f.caidi_ex_med) OVER (PARTITION BY f.utility_key ORDER BY f.year)          AS caidi_ex_med_py,
  f.saidi_ex_med / NULLIF(saidi_ex_med_py,0) - 1                                  AS saidi_yoy,
  -- share of the SAIDI change that came from frequency: ln SAIDI = ln SAIFI + ln CAIDI.
  -- NULLIF(x, 0) feeds LN a NULL instead of a zero: Snowflake raises on LN(0),
  -- some utilities report 0, and LN(NULL) returns NULL.
  -- When SAIDI changes by under about 2%, the denominator is near zero
  -- and the attributed frequency share becomes misleadingly extreme.
  CASE
    WHEN ABS(LN(NULLIF(f.saidi_ex_med, 0) / NULLIF(saidi_ex_med_py, 0))) < 0.02
      THEN NULL
    ELSE LN(NULLIF(f.saifi_ex_med, 0) / NULLIF(saifi_ex_med_py, 0))
      / NULLIF(LN(NULLIF(f.saidi_ex_med, 0) / NULLIF(saidi_ex_med_py, 0)), 0)
  END AS frequency_share_of_change,
  AVG(f.saidi_ex_med) OVER (PARTITION BY f.utility_key ORDER BY f.year
                            ROWS BETWEEN 4 PRECEDING AND CURRENT ROW)             AS saidi_ex_med_5yr,
  AVG(f.saifi_ex_med) OVER (PARTITION BY f.utility_key ORDER BY f.year
                            ROWS BETWEEN 4 PRECEDING AND CURRENT ROW)             AS saifi_ex_med_5yr
FROM RELIABILITY.MART.FCT_RELIABILITY f
JOIN RELIABILITY.MART.DIM_UTILITY d USING (utility_key);

-- Customer-weighted indices by peer group (used for the co-op benchmark).
-- Each denominator counts only the customers of utilities that reported the
-- numerator. A utility that filed SAIDI but not SAIFI (Prince George Electric,
-- 2025) would otherwise dilute the group SAIFI. See docs/03, P18.
CREATE OR REPLACE VIEW RELIABILITY.MART.V_GROUP_INDEX COPY GRANTS AS
SELECT
  d.peer_group, f.year,
  COUNT(*)                                                         AS utilities,
  SUM(f.customers)                                                 AS customers,
  SUM(f.cust_interruptions_ex_med)
    / NULLIF(SUM(CASE WHEN f.cust_interruptions_ex_med IS NOT NULL THEN f.customers END), 0) AS saifi_ex_med,
  SUM(f.cust_minutes_ex_med)
    / NULLIF(SUM(CASE WHEN f.cust_minutes_ex_med IS NOT NULL THEN f.customers END), 0)       AS saidi_ex_med,
  SUM(f.cust_minutes_ex_med) / NULLIF(SUM(f.cust_interruptions_ex_med), 0)                    AS caidi_ex_med
FROM RELIABILITY.MART.FCT_RELIABILITY f
JOIN RELIABILITY.MART.DIM_UTILITY d USING (utility_key)
GROUP BY 1,2;
