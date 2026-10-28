-- =====================================================================
-- DOMINION RELIABILITY MART  |  08: read-only access for Power BI
-- Run as ACCOUNTADMIN, one statement at a time. Replace the password
-- placeholder before running and never commit the real one.
-- =====================================================================

-- One role that can read the mart and nothing else.
CREATE ROLE IF NOT EXISTS BI_READER;

GRANT USAGE ON DATABASE RELIABILITY                     TO ROLE BI_READER;
GRANT USAGE ON SCHEMA   RELIABILITY.MART                TO ROLE BI_READER;
GRANT SELECT ON ALL TABLES    IN SCHEMA RELIABILITY.MART TO ROLE BI_READER;
GRANT SELECT ON ALL VIEWS     IN SCHEMA RELIABILITY.MART TO ROLE BI_READER;

-- CREATE OR REPLACE drops grants on the object it replaces. FUTURE grants
-- mean a rebuilt or newly added mart object is readable without re-granting.
GRANT SELECT ON FUTURE TABLES IN SCHEMA RELIABILITY.MART TO ROLE BI_READER;
GRANT SELECT ON FUTURE VIEWS  IN SCHEMA RELIABILITY.MART TO ROLE BI_READER;

GRANT USAGE ON WAREHOUSE SNOWFLAKE_LEARNING_WH TO ROLE BI_READER;

-- Service user for the Power BI connector. LEGACY_SERVICE is required for
-- username and password authentication from the connector; the default user
-- type fails with an unhelpful error. In a team setting this would be
-- key-pair authentication with the key in a secrets manager.
CREATE USER IF NOT EXISTS POWERBI_SVC
  PASSWORD = '<set-a-strong-password-here-and-do-not-commit-it>'
  TYPE = LEGACY_SERVICE
  DEFAULT_ROLE = BI_READER
  DEFAULT_WAREHOUSE = SNOWFLAKE_LEARNING_WH
  MUST_CHANGE_PASSWORD = FALSE;

GRANT ROLE BI_READER TO USER POWERBI_SVC;

-- Checks
SHOW GRANTS TO ROLE BI_READER;
SHOW GRANTS TO USER POWERBI_SVC;
