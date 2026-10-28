-- =====================================================================
-- DOMINION RELIABILITY MART  |  04: data quality tests
-- Each query should return zero rows (or the expected count). Run after
-- every load. In Snowflake, wrap them in a TASK scheduled for next October
-- when EIA publishes the next year.
-- =====================================================================

-- T1. No duplicate utility-state-year after de-duplication
SELECT utility_key, year, COUNT(*) AS n
FROM RELIABILITY.MART.FCT_RELIABILITY
GROUP BY 1,2 HAVING COUNT(*) > 1;

-- T2. SAIDI = SAIFI x CAIDI within rounding
SELECT utility_key, year, saidi_ex_med, saifi_ex_med * caidi_ex_med AS recomputed
FROM RELIABILITY.MART.FCT_RELIABILITY
WHERE saifi_ex_med > 0 AND caidi_ex_med > 0
  AND ABS(saidi_ex_med - saifi_ex_med * caidi_ex_med) / saidi_ex_med > 0.02;

-- T3. All-events SAIDI is not lower than ex-MED SAIDI
SELECT utility_key, year, saidi_all, saidi_ex_med
FROM RELIABILITY.MART.FCT_RELIABILITY
WHERE saidi_all < saidi_ex_med - 0.01;

-- T4. Dominion VA 2025 matches EIA's published values
SELECT * FROM RELIABILITY.MART.FCT_RELIABILITY
WHERE utility_key = '19876|VA' AND year = 2025
  AND NOT (saidi_all = 306.7 AND saidi_ex_med = 144.4 AND customers = 2675735);

-- T5. Row counts and customer totals by year
SELECT year, COUNT(*) AS utilities, SUM(customers) AS customers
FROM RELIABILITY.MART.FCT_RELIABILITY GROUP BY year ORDER BY year;

-- T6. Raw numeric values that failed TRY_TO_NUMBER after separator removal
SELECT utility_number, utility_name, state, oth_customers
FROM RELIABILITY.RAW.EIA861_RELIABILITY_2025
WHERE oth_customers IS NOT NULL AND TRY_TO_NUMBER(REPLACE(oth_customers, ',', '')) IS NULL;
