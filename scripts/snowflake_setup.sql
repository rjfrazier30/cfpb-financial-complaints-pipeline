-- ============================================================
-- CFPB Financial Complaints Pipeline — Snowflake Setup
-- Run this once in the Snowflake UI (Snowsight) to create
-- the warehouse, database, schemas, and raw table.
-- ============================================================

-- 1. Create a dedicated warehouse (X-Small keeps costs near $0)
CREATE WAREHOUSE IF NOT EXISTS CFPB_WH
    WITH WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60          -- suspend after 1 min idle
    AUTO_RESUME  = TRUE
    INITIALLY_SUSPENDED = TRUE;

-- 2. Create the database
CREATE DATABASE IF NOT EXISTS CFPB_ANALYTICS;

-- 3. Create schemas that mirror the dbt layer convention
USE DATABASE CFPB_ANALYTICS;

CREATE SCHEMA IF NOT EXISTS RAW;          -- landing zone for ingested data
CREATE SCHEMA IF NOT EXISTS STAGING;      -- cleaned & typed
CREATE SCHEMA IF NOT EXISTS INTERMEDIATE; -- business logic joins
CREATE SCHEMA IF NOT EXISTS MARTS;        -- analytics-ready tables

-- 4. Create the raw complaints table
USE SCHEMA RAW;

DROP TABLE IF EXISTS RAW_COMPLAINTS;

CREATE TABLE IF NOT EXISTS RAW_COMPLAINTS (
    complaint_id            NUMBER          PRIMARY KEY,
    date_received           DATE,
    product                 VARCHAR(256),
    sub_product             VARCHAR(256),
    issue                   VARCHAR(512),
    sub_issue               VARCHAR(512),
    consumer_complaint_narrative TEXT,
    company_public_response VARCHAR(512),
    company                 VARCHAR(256),
    state                   VARCHAR(256),
    zip_code                VARCHAR(256),
    tags                    VARCHAR(128),
    consumer_consent_provided VARCHAR(128),
    submitted_via           VARCHAR(64),
    date_sent_to_company    DATE,
    company_response        VARCHAR(256),
    timely_response         VARCHAR(256),
    consumer_disputed       VARCHAR(256),
    _loaded_at              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- 5. Create a file format for CSV loading (alternative ingestion path)
CREATE FILE FORMAT IF NOT EXISTS RAW.CSV_FORMAT
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    NULL_IF = ('', 'N/A', 'NULL')
    EMPTY_FIELD_AS_NULL = TRUE;

-- 6. Grant usage to the role you'll use with dbt
GRANT USAGE ON WAREHOUSE CFPB_WH TO ROLE SYSADMIN;
GRANT ALL ON DATABASE CFPB_ANALYTICS TO ROLE SYSADMIN;
GRANT ALL ON ALL SCHEMAS IN DATABASE CFPB_ANALYTICS TO ROLE SYSADMIN;

SELECT 'Snowflake setup complete!' AS status;

