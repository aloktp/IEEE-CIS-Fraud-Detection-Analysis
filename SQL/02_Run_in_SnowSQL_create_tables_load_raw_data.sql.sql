-- RUN ALL BELOW COMMANDS IN SNOWSQL IN COMMAND PROMPT.
-- Snowflake Free Trial version has a file upload limit of 250 MB. Hence, cant uplaod train_transaction or train_identity csv files. 
-- Hence, SnowSQl is used

-- Steps below are to Load raw CSV data into Snowflake

-- Set session context

USE WAREHOUSE FRAUD_WH;
USE DATABASE FRAUD_DB;
USE SCHEMA RAW;


-- Create CSV file format
-- PARSE_HEADER=TRUE preserves actual column names

CREATE OR REPLACE FILE FORMAT my_csv_format
TYPE = CSV
FIELD_OPTIONALLY_ENCLOSED_BY = '"'
PARSE_HEADER = TRUE
NULL_IF = ('NULL', 'null', 'NA', '')
-- Null can be stored as string in many different ways in the dataset. This will encompass all Nulls.
EMPTY_FIELD_AS_NULL = TRUE;


-- Create temporary placeholder tables
-- Required because Snowflake table stages (%TABLE_NAME)
-- exist only after table creation

CREATE OR REPLACE TABLE RAW_TRANSACTION (
    DUMMY STRING
);

CREATE OR REPLACE TABLE RAW_IDENTITY (
    DUMMY STRING
);


-- Upload CSV files to Snowflake table stages
-- NOTE:
-- PUT commands run in SnowSQL CLI only
-- Change your filepath accordingly

PUT 'file://C:/Users/username/train_transaction.csv'
@%RAW_TRANSACTION
AUTO_COMPRESS=TRUE
OVERWRITE=TRUE;

PUT 'file://C:/Users/username/train_identity.csv'
@%RAW_IDENTITY
AUTO_COMPRESS=TRUE
OVERWRITE=TRUE;

-- ---------------------------------------------------------
-- Infer schema and create RAW_TRANSACTION table
-- ---------------------------------------------------------

CREATE OR REPLACE TABLE RAW_TRANSACTION
USING TEMPLATE (
    SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*))
    FROM TABLE(
        INFER_SCHEMA(
            LOCATION => '@%RAW_TRANSACTION',
            FILE_FORMAT => 'my_csv_format'
        )
    )
);

-- ---------------------------------------------------------
-- Infer schema and create RAW_IDENTITY table
-- ---------------------------------------------------------

CREATE OR REPLACE TABLE RAW_IDENTITY
USING TEMPLATE (
    SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*))
    FROM TABLE(
        INFER_SCHEMA(
            LOCATION => '@%RAW_IDENTITY',
            FILE_FORMAT => 'my_csv_format'
        )
    )
);

-- -----------------------------------------------------------------------
-- Verify inferred schema. Lists all column names and datatypes of columns
-- -----------------------------------------------------------------------

DESC TABLE RAW_TRANSACTION;
DESC TABLE RAW_IDENTITY;

-- ---------------------------------------------------------
-- Load transaction dataset
-- MATCH_BY_COLUMN_NAME maps CSV headers correctly
-- ---------------------------------------------------------

COPY INTO RAW_TRANSACTION
FROM @%RAW_TRANSACTION
FILE_FORMAT = (
    FORMAT_NAME = 'my_csv_format'
)
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- ---------------------------------------------------------
-- Load identity dataset
-- ---------------------------------------------------------

COPY INTO RAW_IDENTITY
FROM @%RAW_IDENTITY
FILE_FORMAT = (
    FORMAT_NAME = 'my_csv_format'
)
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- ---------------------------------------------------------
-- Validate row counts
-- ---------------------------------------------------------

SELECT COUNT(*) AS transaction_rows
FROM RAW_TRANSACTION;

-- Expected:
-- transaction_rows = 590540

SELECT COUNT(*) AS identity_rows
FROM RAW_IDENTITY;

-- Expected:
-- identity_rows    = 144233

-- Preview data
SELECT * FROM FRAUD_DB.RAW.RAW_TRANSACTION LIMIT 5;
SELECT * FROM FRAUD_DB.RAW.RAW_IDENTITY LIMIT 5;-- Confirm fraud distribution
SELECT
ISFRAUD,
COUNT(*) AS n,
ROUND(COUNT(*)*100.0 / SUM(COUNT(*)) OVER(), 2) AS pct
FROM FRAUD_DB.RAW.RAW_TRANSACTION
GROUP BY ISFRAUD;-- Expected: 0 = 96.5%, 1 = 3.5%