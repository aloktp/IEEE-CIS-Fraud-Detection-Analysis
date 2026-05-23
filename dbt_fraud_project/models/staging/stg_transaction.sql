{{ config(materialized='table', schema='STAGING') }}

SELECT
    "TransactionID"                                      AS TransactionID,
    "isFraud"                                            AS isFraud,
    "TransactionDT"                                      AS TransactionDT,

    -- TIME FEATURES
    -- TransactionDT is a timedelta in seconds, NOT a real timestamp.
    FLOOR(("TransactionDT" % 86400) / 3600)              AS txn_hour,
    FLOOR(("TransactionDT" / 86400) % 7)                 AS txn_day_of_week,
    -- txn_day_number kept for window function ordering in feat_velocity.
    -- Not a predictive feature. Not passed to ML.
    FLOOR("TransactionDT" / 86400)                       AS txn_day_number,

    -- AMOUNT FEATURES
    "TransactionAmt"                                     AS TransactionAmt,
    -- Take natural log to reduce skew from large non-fraud outliers (>$30,000).
    -- Stabilizes variance and makes fraud vs non-fraud distributions more comparable.
    LN("TransactionAmt" + 1)                             AS log_txn_amt,
    -- Fraudsters sometimes use round amounts like $100.00 exactly.
    ROUND("TransactionAmt" - FLOOR("TransactionAmt"), 4) AS amt_decimal_part,

    "ProductCD"                                          AS ProductCD,

    -- CARD FEATURES
    -- card1, card2, card3, card5 are numeric. Few nulls. Model learns directly.
    "card1"                                              AS card1,
    "card2"                                              AS card2,
    "card3"                                              AS card3,
    -- card4: string (visa, mastercard). NULL replaced with 'unknown'.
    COALESCE("card4", 'unknown')                         AS card4_clean,
    "card5"                                              AS card5,
    -- card6: string (debit, credit). NULL replaced with 'unknown'.
    COALESCE("card6", 'unknown')                         AS card6_clean,

    -- ADDRESS AND DISTANCE
    -- dist1/dist2 are sparse. addr1/addr2 have more data and stronger signal.
    -- -999 sentinel so model learns from missingness pattern.
    COALESCE("addr1", -999)                              AS addr1_clean,
    COALESCE("addr2", -999)                              AS addr2_clean,
    COALESCE("dist1", -999)                              AS dist1_clean,
    COALESCE("dist2", -999)                              AS dist2_clean,

    -- EMAIL DOMAINS
    -- Raw cleaned versions kept for dashboard use only.
    -- p_email_group / r_email_group are what go into ML.
    -- Grouped to prevent model overfitting to individual domain names.
    COALESCE("P_emaildomain", 'unknown')                 AS p_email_clean,
    COALESCE("R_emaildomain", 'unknown')                 AS r_email_clean,

    CASE
        WHEN "P_emaildomain" LIKE '%gmail%'              THEN 'gmail'
        WHEN "P_emaildomain" LIKE '%yahoo%'              THEN 'yahoo'
        WHEN "P_emaildomain" LIKE '%outlook%'            THEN 'outlook'
        WHEN "P_emaildomain" LIKE '%hotmail%'            THEN 'hotmail'
        WHEN "P_emaildomain" IS NULL                     THEN 'unknown'
        ELSE 'other'
    END AS p_email_group,

    CASE
        WHEN "R_emaildomain" LIKE '%gmail%'              THEN 'gmail'
        WHEN "R_emaildomain" LIKE '%yahoo%'              THEN 'yahoo'
        WHEN "R_emaildomain" LIKE '%outlook%'            THEN 'outlook'
        WHEN "R_emaildomain" LIKE '%hotmail%'            THEN 'hotmail'
        WHEN "R_emaildomain" IS NULL                     THEN 'unknown'
        ELSE 'other'
    END AS r_email_group,

    -- MATCH FLAGS M1-M9
    -- T/F strings converted to binary integers.
    -- Match features e.g. name on card matches billing address.
    CASE WHEN "M1" = 'T' THEN 1 ELSE 0 END              AS m1_flag,
    CASE WHEN "M2" = 'T' THEN 1 ELSE 0 END              AS m2_flag,
    CASE WHEN "M3" = 'T' THEN 1 ELSE 0 END              AS m3_flag,
    -- M4 has values M0, M1, M2, NULL. Treated as categorical not binary.
    COALESCE("M4", 'unknown')                            AS m4_clean,
    CASE WHEN "M5" = 'T' THEN 1 ELSE 0 END              AS m5_flag,
    CASE WHEN "M6" = 'T' THEN 1 ELSE 0 END              AS m6_flag,
    CASE WHEN "M7" = 'T' THEN 1 ELSE 0 END              AS m7_flag,
    CASE WHEN "M8" = 'T' THEN 1 ELSE 0 END              AS m8_flag,
    CASE WHEN "M9" = 'T' THEN 1 ELSE 0 END              AS m9_flag,

    -- COUNT COLUMNS C1-C14
    -- Counting features e.g. how many addresses associated with payment card.
    COALESCE("C1",  -999)                                AS C1,
    COALESCE("C2",  -999)                                AS C2,
    COALESCE("C3",  -999)                                AS C3,
    COALESCE("C4",  -999)                                AS C4,
    COALESCE("C5",  -999)                                AS C5,
    COALESCE("C6",  -999)                                AS C6,
    COALESCE("C7",  -999)                                AS C7,
    COALESCE("C8",  -999)                                AS C8,
    COALESCE("C9",  -999)                                AS C9,
    COALESCE("C10", -999)                                AS C10,
    COALESCE("C11", -999)                                AS C11,
    COALESCE("C12", -999)                                AS C12,
    COALESCE("C13", -999)                                AS C13,
    COALESCE("C14", -999)                                AS C14,

    -- TIME-GAP COLUMNS D1-D15
    -- Timedelta features e.g. days since previous transaction.
    COALESCE("D1",  -999)                                AS D1,
    COALESCE("D2",  -999)                                AS D2,
    COALESCE("D3",  -999)                                AS D3,
    COALESCE("D4",  -999)                                AS D4,
    COALESCE("D5",  -999)                                AS D5,
    COALESCE("D6",  -999)                                AS D6,
    COALESCE("D7",  -999)                                AS D7,
    COALESCE("D8",  -999)                                AS D8,
    COALESCE("D9",  -999)                                AS D9,
    COALESCE("D10", -999)                                AS D10,
    COALESCE("D11", -999)                                AS D11,
    COALESCE("D12", -999)                                AS D12,
    COALESCE("D13", -999)                                AS D13,
    COALESCE("D14", -999)                                AS D14,
    COALESCE("D15", -999)                                AS D15,

    -- V COLUMNS V1-V339
    -- Generated by macro querying INFORMATION_SCHEMA at compile time.
    -- Remaining nulls handled by df.fillna(-999) in fraud_ml.py.
    {{ coalesce_v_columns('RAW', 'RAW_TRANSACTION') }}

FROM {{ source('raw', 'RAW_TRANSACTION') }}