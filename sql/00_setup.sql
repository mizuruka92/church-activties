-- =============================================================================
-- Step 0: Session check (optional, read-only)
--
-- Purpose : Show which role and warehouse the current session uses, before any
--           object is created. This file does not create or change anything.
-- Warehouse: The project deliberately does NOT assume a warehouse name or role.
--           Pick a warehouse in the Snowsight UI (a trial account normally has
--           one already), or use the optional example at the bottom.
-- Safe to re-run: yes.
-- =============================================================================

-- ACTIVE_WAREHOUSE is NULL when no warehouse has been selected yet.
SELECT
    CURRENT_ACCOUNT()   AS ACCOUNT_NAME,
    CURRENT_USER()      AS USER_NAME,
    CURRENT_ROLE()      AS ACTIVE_ROLE,
    CURRENT_WAREHOUSE() AS ACTIVE_WAREHOUSE;

-- -----------------------------------------------------------------------------
-- OPTIONAL: create a small dedicated warehouse. Commented out on purpose.
-- Uncomment only if your account has no usable warehouse and your role may
-- create one. The name PIP_DEMO_WH is just an example.
-- -----------------------------------------------------------------------------
-- CREATE WAREHOUSE IF NOT EXISTS PIP_DEMO_WH
--     WITH WAREHOUSE_SIZE = 'XSMALL'
--     AUTO_SUSPEND = 60
--     AUTO_RESUME = TRUE
--     INITIALLY_SUSPENDED = TRUE;
-- USE WAREHOUSE PIP_DEMO_WH;
