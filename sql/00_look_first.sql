-- =====================================================================
-- DOMINION RELIABILITY MART  |  00: profiling queries on the RAW tables
-- Run after COPY INTO. Expected results are noted beside each query. A
-- different result indicates a change in the load or the source file.
-- =====================================================================

-- A. Locate Dominion. The EIA filing uses the legal name Virginia Electric &
--    Power Co, utility number 19876.
SELECT utility_number, utility_name, state, ownership, oth_saidi_all, oth_saidi_ex_med, oth_customers
FROM RELIABILITY.RAW.EIA861_RELIABILITY_2025
WHERE utility_name ILIKE '%dominion%';

SELECT utility_number, utility_name, state, ownership,
       ieee_saidi_all, oth_saidi_all, oth_saidi_ex_med, oth_saifi_ex_med, oth_caidi_ex_med,
       oth_customers, oth_max_kv, oth_auto_recorded
FROM RELIABILITY.RAW.EIA861_RELIABILITY_2025
WHERE utility_number = '19876';

-- B. Which block did each utility fill in? (expected 751 / 212 / 1 / 13 / 977)
SELECT
  SUM(CASE WHEN ieee_saidi_all IS NOT NULL AND oth_saidi_all IS NULL THEN 1 ELSE 0 END) AS ieee_only,
  SUM(CASE WHEN ieee_saidi_all IS NULL AND oth_saidi_all IS NOT NULL THEN 1 ELSE 0 END) AS other_only,
  SUM(CASE WHEN ieee_saidi_all IS NOT NULL AND oth_saidi_all IS NOT NULL THEN 1 ELSE 0 END) AS both_blocks,
  SUM(CASE WHEN ieee_saidi_all IS NULL AND oth_saidi_all IS NULL THEN 1 ELSE 0 END) AS neither,
  COUNT(*) AS rows_total
FROM RELIABILITY.RAW.EIA861_RELIABILITY_2025;

-- C. Will the numbers parse? (expected 961 rows with a comma, 750 would fail)
SELECT COUNT(*) AS rows_with_comma
FROM RELIABILITY.RAW.EIA861_RELIABILITY_2025
WHERE ieee_customers LIKE '%,%' OR oth_customers LIKE '%,%';

SELECT COUNT(*) AS would_fail
FROM RELIABILITY.RAW.EIA861_RELIABILITY_2025
WHERE ieee_customers IS NOT NULL AND TRY_TO_NUMBER(ieee_customers) IS NULL;

-- D. PUDL includes a row for both standards for every utility, including empty rows
SELECT standard, COUNT(*) AS rows_,
       SUM(CASE WHEN saidi_w_med IS NULL AND saidi_wo_med IS NULL THEN 1 ELSE 0 END) AS empty_rows
FROM RELIABILITY.RAW.PUDL_RELIABILITY GROUP BY 1;

SELECT YEAR(TRY_TO_DATE(report_date)) AS yr, COUNT(*) AS rows_,
       COUNT(DISTINCT utility_id_eia || '|' || state) AS utilities
FROM RELIABILITY.RAW.PUDL_RELIABILITY GROUP BY 1 ORDER BY 1;

-- E. Dominion by year, raw. Automated recording starts in 2015. Highest voltage changes from 34.5 kV to 46 kV in 2020.
SELECT report_date, standard, saidi_w_med, saidi_wo_med, saifi_wo_med, caidi_wo_med, customers,
       outages_recorded_automatically, highest_distribution_voltage_kv
FROM RELIABILITY.RAW.PUDL_RELIABILITY
WHERE utility_id_eia = '19876' AND state = 'VA'
ORDER BY report_date, standard;

-- F. After the staging views exist: the duplicates that QUALIFY removes (expected 7 rows)
WITH u AS (
  SELECT * FROM RELIABILITY.STG.RELIABILITY_HIST
  UNION ALL
  SELECT * FROM RELIABILITY.STG.RELIABILITY_2025
)
SELECT utility_id, state, year, COUNT(*) AS n, LISTAGG(standard, ' + ') AS standards
FROM u GROUP BY 1, 2, 3 HAVING COUNT(*) > 1 ORDER BY year, utility_id;

-- G. After the staging views exist: mean of ratios vs customer-weighted ratio.
--    Expected 2.439 vs 1.887: ten co-ops filed and nine reported a SAIFI. The
--    weighted figure divides by the customers of those nine.
SELECT ROUND(AVG(saifi_ex_med), 3)                                                  AS avg_of_ratios,
       ROUND(SUM(saifi_ex_med * customers)
             / SUM(CASE WHEN saifi_ex_med IS NOT NULL THEN customers END), 3)       AS customer_weighted,
       COUNT(*)                                                                     AS coops_filed,
       COUNT(saifi_ex_med)                                                          AS coops_with_saifi
FROM RELIABILITY.STG.RELIABILITY
WHERE state = 'VA' AND entity_type = 'Cooperative' AND year = 2025;
