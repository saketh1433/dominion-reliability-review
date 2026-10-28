-- =====================================================================
-- DOMINION RELIABILITY MART  |  03: the analysis queries, one per question
-- =====================================================================

-- Q1. Is Dominion getting more or less reliable, and is it frequency or duration?
-- Q1a: the trend with year-on-year decomposition
SELECT year, standard, saidi_ex_med, saifi_ex_med, caidi_ex_med,
       ROUND(saidi_yoy * 100, 1)                  AS saidi_yoy_pct,
       ROUND(frequency_share_of_change * 100, 0)   AS pct_of_change_from_frequency
FROM RELIABILITY.MART.V_TREND
WHERE utility_key = '19876|VA'
ORDER BY year;

-- Q1b: period decomposition (2019->2023 and 2023->2025)
WITH p AS (
  SELECT year, saidi_ex_med, saifi_ex_med, caidi_ex_med
  FROM RELIABILITY.MART.FCT_RELIABILITY WHERE utility_key = '19876|VA'
)
SELECT a.year AS from_year, b.year AS to_year,
       ROUND((b.saidi_ex_med / a.saidi_ex_med - 1) * 100, 1)                                   AS saidi_change_pct,
       ROUND(LN(b.saifi_ex_med / a.saifi_ex_med) / LN(b.saidi_ex_med / a.saidi_ex_med) * 100, 0) AS pct_from_frequency,
       ROUND(LN(b.caidi_ex_med / a.caidi_ex_med) / LN(b.saidi_ex_med / a.saidi_ex_med) * 100, 0) AS pct_from_duration
FROM p a JOIN p b ON (a.year, b.year) IN ((2019, 2023), (2023, 2025), (2015, 2025))
ORDER BY 1;

-- Q2. How much is weather? Storm vs day-to-day minutes
SELECT year, saidi_all, saidi_ex_med, storm_saidi,
       ROUND(storm_share * 100, 0)                                  AS storm_share_pct,
       ROUND(storm_saidi / NULLIF(saifi_all - saifi_ex_med, 0), 0)  AS storm_caidi_minutes
FROM RELIABILITY.MART.V_TREND
WHERE utility_key = '19876|VA'
ORDER BY year;

-- Q2b: do storm minutes and day-to-day minutes move together?
SELECT ROUND(CORR(storm_saidi, saidi_ex_med), 2) AS corr_storm_vs_daytoday
FROM RELIABILITY.MART.FCT_RELIABILITY
WHERE utility_key = '19876|VA';

-- Q3. Fair comparison: Dominion vs Virginia co-ops in the same weather
-- Q3a: balanced panel of co-ops (>=10k customers, filed every year 2015-2025)
CREATE OR REPLACE VIEW RELIABILITY.MART.V_VA_COOP_PANEL AS
SELECT f.utility_key
FROM RELIABILITY.MART.FCT_RELIABILITY f
JOIN RELIABILITY.MART.DIM_UTILITY d USING (utility_key)
WHERE d.peer_group = 'Virginia co-op' AND f.year BETWEEN 2015 AND 2025
GROUP BY f.utility_key
HAVING COUNT(DISTINCT f.year) = 11 AND MAX(f.customers) >= 10000;

-- Q3b: Dominion vs the co-op index, year by year
WITH coop AS (
  SELECT year,
         SUM(cust_interruptions_ex_med) / SUM(customers) AS coop_saifi,
         SUM(cust_minutes_ex_med)       / SUM(customers) AS coop_saidi,
         COUNT(*) AS n_coops
  FROM RELIABILITY.MART.FCT_RELIABILITY
  WHERE utility_key IN (SELECT utility_key FROM RELIABILITY.MART.V_VA_COOP_PANEL)
  GROUP BY year
), dom AS (
  SELECT year, saifi_ex_med AS dom_saifi, saidi_ex_med AS dom_saidi
  FROM RELIABILITY.MART.FCT_RELIABILITY WHERE utility_key = '19876|VA'
)
SELECT d.year, n_coops,
       ROUND(dom_saifi, 3) AS dom_saifi, ROUND(coop_saifi, 3) AS coop_saifi,
       ROUND(dom_saifi / coop_saifi, 3) AS dom_relative_to_coops,
       ROUND(dom_saifi / LAG(dom_saifi)  OVER (ORDER BY d.year) - 1, 3) AS dom_yoy,
       ROUND(coop_saifi / LAG(coop_saifi) OVER (ORDER BY d.year) - 1, 3) AS coop_yoy
FROM dom d JOIN coop c USING (year)
WHERE d.year >= 2015
ORDER BY year;

-- Q3c: the two headline numbers. Correlation of yearly % changes, and the
-- change in Dominion's position relative to the co-ops (3-year averages)
WITH coop AS (
  SELECT year, SUM(cust_interruptions_ex_med) / SUM(customers) AS coop_saifi
  FROM RELIABILITY.MART.FCT_RELIABILITY
  WHERE utility_key IN (SELECT utility_key FROM RELIABILITY.MART.V_VA_COOP_PANEL)
  GROUP BY year
), j AS (
  SELECT f.year, f.saifi_ex_med AS dom_saifi, c.coop_saifi,
         LN(f.saifi_ex_med / LAG(f.saifi_ex_med) OVER (ORDER BY f.year)) AS dom_dlog,
         LN(c.coop_saifi    / LAG(c.coop_saifi)  OVER (ORDER BY f.year)) AS coop_dlog
  FROM RELIABILITY.MART.FCT_RELIABILITY f JOIN coop c USING (year)
  WHERE f.utility_key = '19876|VA' AND f.year >= 2015
)
SELECT
  ROUND(CORR(dom_dlog, coop_dlog), 2)                                                        AS corr_of_yoy_changes,
  ROUND(AVG(CASE WHEN year BETWEEN 2015 AND 2017 THEN dom_saifi / coop_saifi END), 3)         AS relative_2015_17,
  ROUND(AVG(CASE WHEN year BETWEEN 2023 AND 2025 THEN dom_saifi / coop_saifi END), 3)         AS relative_2023_25,
  ROUND((relative_2023_25 / relative_2015_17 - 1) * 100, 1)                                   AS dominion_relative_improvement_pct
FROM j;

-- Q3d: leave-one-out robustness. Does any single co-op drive the result?
WITH panel AS (SELECT utility_key FROM RELIABILITY.MART.V_VA_COOP_PANEL),
dom AS (SELECT year, saifi_ex_med AS dom_saifi FROM RELIABILITY.MART.FCT_RELIABILITY WHERE utility_key = '19876|VA'),
loo AS (
  SELECT p.utility_key AS dropped, f.year,
         SUM(f.cust_interruptions_ex_med) / SUM(f.customers) AS coop_saifi
  FROM panel p
  JOIN RELIABILITY.MART.FCT_RELIABILITY f
    ON f.utility_key IN (SELECT utility_key FROM panel) AND f.utility_key <> p.utility_key
  GROUP BY p.utility_key, f.year
)
SELECT d2.utility_name AS dropped_coop,
       ROUND(AVG(CASE WHEN l.year BETWEEN 2015 AND 2017 THEN dom_saifi / coop_saifi END), 3) AS rel_2015_17,
       ROUND(AVG(CASE WHEN l.year BETWEEN 2023 AND 2025 THEN dom_saifi / coop_saifi END), 3) AS rel_2023_25,
       ROUND((rel_2023_25 / rel_2015_17 - 1) * 100, 1) AS dominion_relative_improvement_pct
FROM loo l JOIN dom USING (year) JOIN RELIABILITY.MART.DIM_UTILITY d2 ON d2.utility_key = l.dropped
GROUP BY 1 ORDER BY 4;

-- Q4. Could smart meters be inflating measured frequency?
-- Event study across all IOUs: SAIFI (net of the national year median) before
-- and after the year AMI share first passed 50%, for utilities below 20% two years earlier.
WITH base AS (
  SELECT f.utility_key, f.year, f.standard, a.ami_share,
         LN(f.saifi_ex_med) - MEDIAN(LN(f.saifi_ex_med)) OVER (PARTITION BY f.year) AS lsaifi_adj
  FROM RELIABILITY.MART.FCT_RELIABILITY f
  JOIN RELIABILITY.MART.DIM_UTILITY d USING (utility_key)
  LEFT JOIN RELIABILITY.STG.AMI a ON a.utility_id = f.utility_id AND a.state = f.state AND a.year = f.year
  WHERE d.entity_type = 'Investor Owned' AND f.customers >= 100000 AND f.saifi_ex_med > 0
),
one_std AS (SELECT utility_key FROM base GROUP BY 1 HAVING COUNT(DISTINCT standard) = 1),
rollout AS (
  SELECT utility_key, MIN(year) AS y0 FROM base WHERE ami_share >= 0.5 GROUP BY 1
),
eligible AS (
  SELECT r.utility_key, r.y0
  FROM rollout r
  JOIN base b ON b.utility_key = r.utility_key AND b.year = r.y0 - 2
  WHERE b.ami_share < 0.2 AND r.utility_key IN (SELECT utility_key FROM one_std)
),
rel AS (
  SELECT b.utility_key, b.year - e.y0 AS years_from_rollout,
         b.lsaifi_adj - b0.lsaifi_adj AS change_vs_two_years_before
  FROM eligible e
  JOIN base b  ON b.utility_key = e.utility_key
  JOIN base b0 ON b0.utility_key = e.utility_key AND b0.year = e.y0 - 2
  WHERE b.year BETWEEN e.y0 - 3 AND e.y0 + 3
)
SELECT years_from_rollout, COUNT(*) AS utilities,
       ROUND(AVG(change_vs_two_years_before) * 100, 1)    AS avg_change_pct,
       ROUND(MEDIAN(change_vs_two_years_before) * 100, 1) AS median_change_pct
FROM rel GROUP BY 1 ORDER BY 1;

-- Q5. Load growth that SAIDI cannot see: Dominion VA sales by class
SELECT year,
       SUM(CASE WHEN customer_class = 'commercial'  THEN sales_mwh END) / 1e6 AS commercial_twh,
       SUM(CASE WHEN customer_class = 'residential' THEN sales_mwh END) / 1e6 AS residential_twh,
       SUM(CASE WHEN customer_class = 'commercial'  AND service_type = 'bundled' THEN customers END) AS commercial_customers
FROM RELIABILITY.STG.SALES
WHERE utility_id = 19876 AND state = 'VA' AND year >= 2013
GROUP BY year ORDER BY year;
