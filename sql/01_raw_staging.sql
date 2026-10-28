-- =====================================================================
-- DOMINION RELIABILITY MART  |  01: raw tables and staging views
-- Snowflake SQL. The same files run on DuckDB through scripts/run_local_duckdb.py
-- for the syntax common to both. Snowflake-only pieces (stages, file
-- formats, COPY INTO) are marked.
-- =====================================================================

-- ---------- 0. Setup (Snowflake only) ----------
CREATE DATABASE IF NOT EXISTS RELIABILITY;
CREATE SCHEMA IF NOT EXISTS RELIABILITY.RAW;
CREATE SCHEMA IF NOT EXISTS RELIABILITY.STG;
CREATE SCHEMA IF NOT EXISTS RELIABILITY.MART;
USE WAREHOUSE SNOWFLAKE_LEARNING_WH;   -- X-Small, auto-resumes

-- One file format for EIA's Excel-exported CSVs and one for PUDL's clean CSVs
CREATE OR REPLACE FILE FORMAT RELIABILITY.RAW.FF_EIA_CSV
  TYPE = CSV
  SKIP_HEADER = 3                      -- EIA has three header rows
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'   -- "2,675,735" comes quoted
  NULL_IF = ('.', '')                  -- EIA uses "." for blank
  EMPTY_FIELD_AS_NULL = TRUE;

CREATE OR REPLACE FILE FORMAT RELIABILITY.RAW.FF_PUDL_CSV
  TYPE = CSV
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  NULL_IF = ('', 'NULL', '<NA>');

CREATE STAGE IF NOT EXISTS RELIABILITY.RAW.EIA_STAGE FILE_FORMAT = RELIABILITY.RAW.FF_EIA_CSV;
CREATE STAGE IF NOT EXISTS RELIABILITY.RAW.PUDL_STAGE FILE_FORMAT = RELIABILITY.RAW.FF_PUDL_CSV;
-- Upload via Snowsight (Data > Add Data > Load files into a stage) or SnowSQL:
--   PUT file:///path/Reliability_2025_States.csv @RELIABILITY.RAW.EIA_STAGE;

-- ---------- 1. Raw tables: land everything as text ----------
-- Why text: the EIA export carries "1,115.500" and ".", so typing happens in
-- staging where it is visible and testable, not inside COPY where it is not.
CREATE OR REPLACE TABLE RELIABILITY.RAW.EIA861_RELIABILITY_2025 (
  data_year            VARCHAR, utility_number VARCHAR, utility_name VARCHAR,
  state                VARCHAR, ownership      VARCHAR,
  -- IEEE block (Schedule 3 Part B)
  ieee_saidi_all       VARCHAR, ieee_saifi_all VARCHAR, ieee_caidi_all VARCHAR,
  ieee_saidi_ex_med    VARCHAR, ieee_saifi_ex_med VARCHAR, ieee_caidi_ex_med VARCHAR,
  ieee_saidi_los       VARCHAR, ieee_saifi_los VARCHAR, ieee_caidi_los VARCHAR,
  ieee_customers       VARCHAR, ieee_max_kv VARCHAR, ieee_auto_recorded VARCHAR,
  -- Other-standard block (Schedule 3 Part C)
  oth_saidi_all        VARCHAR, oth_saifi_all VARCHAR, oth_caidi_all VARCHAR,
  oth_saidi_ex_med     VARCHAR, oth_saifi_ex_med VARCHAR, oth_caidi_ex_med VARCHAR,
  oth_customers        VARCHAR, oth_inactive_included VARCHAR, oth_momentary_def VARCHAR,
  oth_max_kv           VARCHAR, oth_auto_recorded VARCHAR
);

CREATE OR REPLACE TABLE RELIABILITY.RAW.PUDL_RELIABILITY (
  caidi_w_med_minus_los VARCHAR, caidi_w_med VARCHAR, caidi_wo_med VARCHAR,
  customers VARCHAR, entity_type VARCHAR, highest_distribution_voltage_kv VARCHAR,
  inactive_accounts_included VARCHAR, momentary_interruption_definition VARCHAR,
  outages_recorded_automatically VARCHAR, report_date VARCHAR,
  saidi_w_med_minus_los VARCHAR, saidi_w_med VARCHAR, saidi_wo_med VARCHAR,
  saifi_w_med VARCHAR, saifi_w_med_minus_los VARCHAR, saifi_wo_med VARCHAR,
  short_form VARCHAR, standard VARCHAR, state VARCHAR, utility_id_eia VARCHAR,
  utility_name_eia VARCHAR, data_maturity VARCHAR
);

CREATE OR REPLACE TABLE RELIABILITY.RAW.PUDL_AMI (
  advanced_metering_infrastructure VARCHAR, automated_meter_reading VARCHAR,
  balancing_authority_code_eia VARCHAR, customer_class VARCHAR,
  daily_digital_access_customers VARCHAR, direct_load_control_customers VARCHAR,
  energy_served_ami_mwh VARCHAR, entity_type VARCHAR, home_area_network VARCHAR,
  non_amr_ami VARCHAR, report_date VARCHAR, short_form VARCHAR, state VARCHAR,
  utility_id_eia VARCHAR, utility_name_eia VARCHAR, data_maturity VARCHAR
);

CREATE OR REPLACE TABLE RELIABILITY.RAW.PUDL_SALES (
  utility_id_eia VARCHAR, state VARCHAR, report_date VARCHAR,
  balancing_authority_code_eia VARCHAR, customer_class VARCHAR, business_model VARCHAR,
  data_observed VARCHAR, entity_type VARCHAR, service_type VARCHAR, short_form VARCHAR,
  utility_name_eia VARCHAR, customers VARCHAR, sales_mwh VARCHAR, sales_revenue VARCHAR,
  data_maturity VARCHAR
);

-- Load the four files from the stages (upload them through Snowsight first:
-- Databases > RELIABILITY > RAW > Stages > EIA_STAGE / PUDL_STAGE > + Files)
COPY INTO RELIABILITY.RAW.EIA861_RELIABILITY_2025 FROM @RELIABILITY.RAW.EIA_STAGE/Reliability_2025_States.csv;
COPY INTO RELIABILITY.RAW.PUDL_RELIABILITY FROM @RELIABILITY.RAW.PUDL_STAGE/pudl_reliability_2013_2024.csv;
COPY INTO RELIABILITY.RAW.PUDL_AMI   FROM @RELIABILITY.RAW.PUDL_STAGE/pudl_ami.csv;
COPY INTO RELIABILITY.RAW.PUDL_SALES FROM @RELIABILITY.RAW.PUDL_STAGE/pudl_sales.csv;

-- Check: expected 977, 24358, 127720, 198770
SELECT 'eia_2025' AS t, COUNT(*) AS n FROM RELIABILITY.RAW.EIA861_RELIABILITY_2025
UNION ALL SELECT 'pudl_rel',   COUNT(*) FROM RELIABILITY.RAW.PUDL_RELIABILITY
UNION ALL SELECT 'pudl_ami',   COUNT(*) FROM RELIABILITY.RAW.PUDL_AMI
UNION ALL SELECT 'pudl_sales', COUNT(*) FROM RELIABILITY.RAW.PUDL_SALES;

-- ---------- 2. Staging: one typed row per utility, state, year ----------
-- EIA 2025: unpivot the two blocks into one shape. A utility that filed IEEE
-- gets the IEEE row, one that filed "Other" gets that row.
CREATE OR REPLACE VIEW RELIABILITY.STG.RELIABILITY_2025 AS
WITH t AS (
  SELECT
    TRY_TO_NUMBER(data_year)      AS year,
    TRY_TO_NUMBER(utility_number) AS utility_id,
    utility_name, state, ownership AS entity_type,
    'IEEE 1366' AS standard,
    TRY_TO_NUMBER(REPLACE(ieee_saidi_all,   ',',''), 12, 3) AS saidi_all,
    TRY_TO_NUMBER(REPLACE(ieee_saifi_all,   ',',''), 12, 3) AS saifi_all,
    TRY_TO_NUMBER(REPLACE(ieee_caidi_all,   ',',''), 12, 3) AS caidi_all,
    TRY_TO_NUMBER(REPLACE(ieee_saidi_ex_med,',',''), 12, 3) AS saidi_ex_med,
    TRY_TO_NUMBER(REPLACE(ieee_saifi_ex_med,',',''), 12, 3) AS saifi_ex_med,
    TRY_TO_NUMBER(REPLACE(ieee_caidi_ex_med,',',''), 12, 3) AS caidi_ex_med,
    TRY_TO_NUMBER(REPLACE(ieee_saidi_los,   ',',''), 12, 3) AS saidi_all_minus_los,
    TRY_TO_NUMBER(REPLACE(ieee_customers,   ',',''))        AS customers,
    TRY_TO_NUMBER(ieee_max_kv, 6, 1)                         AS max_kv,
    ieee_auto_recorded = 'Y'                                 AS auto_recorded,
    NULL::VARCHAR                                            AS momentary_def,
    NULL::BOOLEAN                                            AS inactive_included
  FROM RELIABILITY.RAW.EIA861_RELIABILITY_2025
  WHERE ieee_saidi_all IS NOT NULL OR ieee_saidi_ex_med IS NOT NULL
  UNION ALL
  SELECT
    TRY_TO_NUMBER(data_year), TRY_TO_NUMBER(utility_number),
    utility_name, state, ownership,
    'Other',
    TRY_TO_NUMBER(REPLACE(oth_saidi_all,   ',',''), 12, 3),
    TRY_TO_NUMBER(REPLACE(oth_saifi_all,   ',',''), 12, 3),
    TRY_TO_NUMBER(REPLACE(oth_caidi_all,   ',',''), 12, 3),
    TRY_TO_NUMBER(REPLACE(oth_saidi_ex_med,',',''), 12, 3),
    TRY_TO_NUMBER(REPLACE(oth_saifi_ex_med,',',''), 12, 3),
    TRY_TO_NUMBER(REPLACE(oth_caidi_ex_med,',',''), 12, 3),
    NULL,
    TRY_TO_NUMBER(REPLACE(oth_customers,   ',','')),
    TRY_TO_NUMBER(oth_max_kv, 6, 1),
    oth_auto_recorded = 'Y',
    oth_momentary_def,
    oth_inactive_included = 'Y'
  FROM RELIABILITY.RAW.EIA861_RELIABILITY_2025
  WHERE oth_saidi_all IS NOT NULL OR oth_saidi_ex_med IS NOT NULL
)
SELECT *, 'EIA-861 final 2025' AS source FROM t;

-- PUDL 2013-2024: already one row per utility-state-year-standard, but both
-- standards appear as rows even when empty, so keep the one with data.
CREATE OR REPLACE VIEW RELIABILITY.STG.RELIABILITY_HIST AS
SELECT
  YEAR(TRY_TO_DATE(report_date))                       AS year,
  TRY_TO_NUMBER(utility_id_eia)                        AS utility_id,
  utility_name_eia                                     AS utility_name,
  state, entity_type,
  CASE standard WHEN 'ieee_standard' THEN 'IEEE 1366' ELSE 'Other' END AS standard,
  TRY_TO_NUMBER(saidi_w_med,  12, 3)                   AS saidi_all,
  TRY_TO_NUMBER(saifi_w_med,  12, 3)                   AS saifi_all,
  TRY_TO_NUMBER(caidi_w_med,  12, 3)                   AS caidi_all,
  TRY_TO_NUMBER(saidi_wo_med, 12, 3)                   AS saidi_ex_med,
  TRY_TO_NUMBER(saifi_wo_med, 12, 3)                   AS saifi_ex_med,
  TRY_TO_NUMBER(caidi_wo_med, 12, 3)                   AS caidi_ex_med,
  TRY_TO_NUMBER(saidi_w_med_minus_los, 12, 3)          AS saidi_all_minus_los,
  TRY_TO_NUMBER(customers)                             AS customers,
  TRY_TO_NUMBER(highest_distribution_voltage_kv, 6, 1) AS max_kv,
  TRY_TO_BOOLEAN(outages_recorded_automatically)       AS auto_recorded,
  momentary_interruption_definition                    AS momentary_def,
  TRY_TO_BOOLEAN(inactive_accounts_included)           AS inactive_included,
  'PUDL (EIA-861) 2013-2024'                            AS source
FROM RELIABILITY.RAW.PUDL_RELIABILITY
WHERE saidi_w_med IS NOT NULL OR saidi_wo_med IS NOT NULL;

-- Union, then de-duplicate: seven small utilities filed BOTH standards in
-- 2021. Keep the IEEE row so customers are not double counted.
CREATE OR REPLACE VIEW RELIABILITY.STG.RELIABILITY AS
SELECT *
FROM (
  SELECT * FROM RELIABILITY.STG.RELIABILITY_HIST
  UNION ALL
  SELECT * FROM RELIABILITY.STG.RELIABILITY_2025
)
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY utility_id, state, year
  ORDER BY CASE standard WHEN 'IEEE 1366' THEN 0 ELSE 1 END
) = 1;

-- Smart meters: sum the customer classes, compute the AMI share
CREATE OR REPLACE VIEW RELIABILITY.STG.AMI AS
SELECT
  TRY_TO_NUMBER(utility_id_eia) AS utility_id, state,
  YEAR(TRY_TO_DATE(report_date)) AS year,
  SUM(TRY_TO_NUMBER(advanced_metering_infrastructure)) AS ami_meters,
  SUM(TRY_TO_NUMBER(automated_meter_reading))          AS amr_meters,
  SUM(TRY_TO_NUMBER(non_amr_ami))                      AS standard_meters,
  ami_meters + COALESCE(amr_meters,0) + COALESCE(standard_meters,0) AS total_meters,
  ami_meters / NULLIF(total_meters,0)                  AS ami_share
FROM RELIABILITY.RAW.PUDL_AMI
GROUP BY 1,2,3;

-- Sales: Dominion VA by class and service type
CREATE OR REPLACE VIEW RELIABILITY.STG.SALES AS
SELECT
  TRY_TO_NUMBER(utility_id_eia) AS utility_id, state,
  YEAR(TRY_TO_DATE(report_date)) AS year,
  customer_class, service_type,
  SUM(TRY_TO_NUMBER(sales_mwh))     AS sales_mwh,
  SUM(TRY_TO_NUMBER(customers))     AS customers,
  SUM(TRY_TO_NUMBER(sales_revenue)) AS revenue_usd
FROM RELIABILITY.RAW.PUDL_SALES
WHERE customer_class <> 'other'
GROUP BY 1,2,3,4,5;
