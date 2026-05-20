/* DATASET DESCRIPTION

Transaction Table :-
TransactionDT: timedelta from a given reference datetime (not an actual timestamp)
TransactionAMT: transaction payment amount in USD
ProductCD: product code, the product for each transaction
card1 - card6: payment card information, such as card type, card category, issue bank, country, etc.
addr: address
dist: distance
P_ and (R__) emaildomain: purchaser and recipient email domain
C1-C14: counting, such as how many addresses are found to be associated with the payment card, etc. The actual meaning is masked.
D1-D15: timedelta, such as days between previous transaction, etc.
M1-M9: match, such as names on card and address, etc.
Vxxx: Vesta engineered rich features, including ranking, counting, and other entity relations.
Categorical Features: ProductCD card1 - card6 addr1, addr2 P_emaildomain R_emaildomain M1 - M9

Identity Table :-
Variables in this table are identity information – network connection information (IP, ISP, Proxy, etc) and digital signature (UA/browser/os/version, etc) associated with transactions. They're collected by Vesta’s fraud protection system and digital security partners. (The field names are masked and pairwise dictionary will not be provided for privacy protection and contract agreement)

Categorical Features: DeviceType DeviceInfo id_12 - id_38

*/

-- CLASS IMBALANCE CHECK

SELECT
"isFraud",
COUNT(*) AS transaction_count,
ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM FRAUD_DB.RAW.RAW_TRANSACTION
GROUP BY "isFraud"
ORDER BY "isFraud";

-- Result: isFraud=0 → ~96.5% | isFraud=1 → ~3.5%-- 
-- This is SEVERE imbalance. 
-- So, we DON'T use accuracy as a metric.
-- We use ROC-AUC as primary metric, and Precision-Recall AUC for imbalanced reporting.
-- Also, we will note down False Negative Rate (missed fraud) and False Positive Rate (customer friction).



-- Time Distribution (TransactionDT Analysis)
-- Which time of day and day of week has more fraud happening ?

-- The timestamp starts from 86400 onwards. So, the time at any transaction is relative to this origination timestamp, and can be gotten by modulus to get hour and day from this origination timestamp. 

SELECT
  FLOOR(("TransactionDT" % 86400) / 3600) AS hour_of_day,
  FLOOR(("TransactionDT" / 86400) % 7) AS day_of_week,
  COUNT(*) AS total_txns,
  SUM("isFraud") AS fraud_count,
  ROUND(SUM("isFraud")*100.0/COUNT(*), 2) AS fraud_rate_pct
FROM FRAUD_DB.RAW.RAW_TRANSACTION
GROUP BY 1, 2
ORDER BY fraud_rate_pct DESC
LIMIT 20;

-- Hour 7 among all hours has highest fraud rate.
-- Day 3 among all hours has highest fraud rate.


-- Transaction Amount Distribution by Fraud
-- Amount in Dataset is in US Dollars

SELECT "isFraud",
ROUND(MIN("TransactionAmt"), 2) AS min_amt,
ROUND(AVG("TransactionAmt"), 2) AS avg_amt,
ROUND(MEDIAN("TransactionAmt"), 2) AS median_amt,
ROUND(MAX("TransactionAmt"), 2) AS max_amt,
ROUND(STDDEV("TransactionAmt"), 2) AS std_amt
FROM FRAUD_DB.RAW.RAW_TRANSACTION
GROUP BY "isFraud";

-- Fraud txns typically have different amount distributions
-- Its obvious that the highest amount of fraud i.e. 5191 dollars being low compared to highest value of 31937 in non-fraud transactions
-- just because fraud transactions are splitted into smaller transactions i.e. "Structuring" or "Smurfing".
-- max values above $30,000 are outliers, which we can find in non-fraud transactions, which will cause instability in the fraud detection model. To reduce its effect, we log-transform before ML model is generated.


-- Email Domain Fraud Rates
-- Which domain i.e. Outlook, Gmail, Hotmail etc. mail addresses are usually fraud

SELECT "P_emaildomain",
COUNT(*) AS total,
SUM("isFraud") AS fraud_count,
ROUND(SUM("isFraud")*100.0/COUNT(*),2) AS fraud_rate_pct
FROM FRAUD_DB.RAW.RAW_TRANSACTION
WHERE "P_emaildomain" IS NOT NULL
GROUP BY "P_emaildomain"
HAVING COUNT(*) > 500
ORDER BY fraud_rate_pct DESC
LIMIT 20;

-- Mail.com, and Outlook.com etc. i.e. anonymous email providers have higher fraud rates.

-- DEVICE TYPE FRAUD ANALYSIS
-- Which device has highest fraud rates. We join Transaction and Identity tables.
-- We do Transactions LEFT join Identity, because transactions having no Identity are a different fraud profile. 

/* 
e.g. 1.) Accounts created without proper KYC; 
2.) Payments made with incomplete or fake personal details; 3.)Anonymous or untraceable digital wallet transfers e.g. crypto transferes where wallet address is not linked to a person i.e. no KYC linkage i.e. Identity remains hidden.
*/

SELECT i."DeviceType",
COUNT(*) AS total,
SUM(t."isFraud") AS fraud_count,
ROUND(SUM(t."isFraud")*100.0/COUNT(*),2) AS fraud_rate_pct
FROM FRAUD_DB.RAW.RAW_TRANSACTION t
LEFT JOIN FRAUD_DB.RAW.RAW_IDENTITY i
ON t."TransactionID" = i."TransactionID"
GROUP BY i."DeviceType"
ORDER BY fraud_rate_pct DESC;

-- Mobile device type has higher fraud rate than Desktop.
-- Null Device Type is also a risky fraud profile. i.e. No device fingerprint, but transactions exist.


-- FEATURE ENGINEERING: Basically, canonicalization OR categorical normalization OR feature standardization
-- Feature Engineering i.e. converting column id_30 into standard categorical features like "Windows" for all Windows versions  : OS Family + Major Version

SELECT
    t."TransactionID",

    /* OS Family */
    CASE
        WHEN i."id_30" ILIKE '%windows%' THEN 'Windows'
        WHEN i."id_30" ILIKE '%mac os%' OR i."id_30" ILIKE '%mac%' THEN 'Mac'
        WHEN i."id_30" ILIKE '%ios%'     THEN 'iOS'
        WHEN i."id_30" ILIKE '%android%' THEN 'Android'
        WHEN i."id_30" ILIKE '%linux%'   THEN 'Linux'
        WHEN i."id_30" IS NULL           THEN 'No Identity Match'
        ELSE 'Other'
    END AS os_family,

    /* OS Version (meaningful splits only) */
    CASE
        WHEN i."id_30" ILIKE '%windows 10%'  THEN 'Windows 10'
        WHEN i."id_30" ILIKE '%windows 7%'   THEN 'Windows 7'
        WHEN i."id_30" ILIKE '%windows 8%'   THEN 'Windows 8/8.1'
        WHEN i."id_30" ILIKE '%windows vista%' THEN 'Windows Vista'
        WHEN i."id_30" ILIKE '%windows xp%'  THEN 'Windows XP'
        WHEN i."id_30" ILIKE '%mac os x 10_13%' OR i."id_30" ILIKE '%mac os x 10.13%' THEN 'macOS High Sierra'
        WHEN i."id_30" ILIKE '%mac os x 10_12%' OR i."id_30" ILIKE '%mac os x 10.12%' THEN 'macOS Sierra'
        WHEN i."id_30" ILIKE '%mac os x 10_11%' OR i."id_30" ILIKE '%mac os x 10.11%' THEN 'OS X El Capitan'
        WHEN i."id_30" ILIKE '%mac os x 10_10%' OR i."id_30" ILIKE '%mac os x 10.10%' THEN 'OS X Yosemite'
        WHEN i."id_30" ILIKE '%mac os x 10_9%'  OR i."id_30" ILIKE '%mac os x 10.9%'  THEN 'OS X Mavericks'
        WHEN i."id_30" ILIKE '%mac os x 10_7%'  OR i."id_30" ILIKE '%mac os x 10.7%'  THEN 'OS X Lion (Old)'
        WHEN i."id_30" ILIKE '%ios 11%'   THEN 'iOS 11'
        WHEN i."id_30" ILIKE '%ios 10%'   THEN 'iOS 10'
        WHEN i."id_30" ILIKE '%ios 9%'    THEN 'iOS 9 (Old)'
        WHEN i."id_30" ILIKE '%android 8%' THEN 'Android 8'
        WHEN i."id_30" ILIKE '%android 7%' THEN 'Android 7'
        WHEN i."id_30" ILIKE '%android 6%' THEN 'Android 6'
        WHEN i."id_30" ILIKE '%android 5%' THEN 'Android 5 (Old)'
        WHEN i."id_30" ILIKE '%android 4%' THEN 'Android 4 (Very Old)'
        WHEN i."id_30" ILIKE '%linux%'    THEN 'Linux'
        WHEN i."id_30" IS NULL            THEN 'No Identity Match'
        ELSE 'Other'
    END AS os_version_group

FROM FRAUD_DB.RAW.RAW_TRANSACTION t
LEFT JOIN FRAUD_DB.RAW.RAW_IDENTITY i ON t."TransactionID" = i."TransactionID";


-- Feature Engineering for id_31 — Browser Family + Version Bucket + Exotic Flag
SELECT
    t."TransactionID",

    /* Browser Family */
    CASE
        WHEN i."id_31" ILIKE '%samsung browser%'              THEN 'Samsung Browser'
        WHEN i."id_31" ILIKE '%mobile safari%'
          OR i."id_31" ILIKE '%safari%'                       THEN 'Safari'
        WHEN i."id_31" ILIKE '%chrome%for android%'
          OR i."id_31" ILIKE '%chrome%for ios%'               THEN 'Chrome Mobile'
        WHEN i."id_31" ILIKE '%chrome%'                       THEN 'Chrome'
        WHEN i."id_31" ILIKE '%firefox%'                      THEN 'Firefox'
        WHEN i."id_31" ILIKE '%edge%'                         THEN 'Edge'
        WHEN i."id_31" ILIKE '%ie%'                           THEN 'IE'
        WHEN i."id_31" ILIKE '%opera%'                        THEN 'Opera'
        WHEN i."id_31" ILIKE '%android webview%'
          OR i."id_31" ILIKE '%mobile%uiwebview%'             THEN 'WebView'
        WHEN i."id_31" ILIKE '%silk%'                         THEN 'Silk (Amazon)'
        WHEN i."id_31" IN (
            'waterfox','cyberfox','palemoon','puffin',
            'seamonkey','iron','comodo','icedragon',
            'maxthon','aol','line'
        )                                                     THEN 'Exotic/Rare Browser'
        WHEN i."id_31" IS NULL                                THEN 'No Identity Match'
        ELSE 'Other'
    END AS browser_family,

    /* Chrome Version Bucket (most traffic, most signal) */
    CASE
        WHEN i."id_31" ILIKE '%chrome%'
        THEN CASE
            WHEN TRY_CAST(REGEXP_SUBSTR(i."id_31", 'chrome ([0-9]+)', 1, 1, 'ie', 1) AS INT) < 55  THEN 'Chrome < 55 (Old)'
            WHEN TRY_CAST(REGEXP_SUBSTR(i."id_31", 'chrome ([0-9]+)', 1, 1, 'ie', 1) AS INT) < 60  THEN 'Chrome 55-59'
            WHEN TRY_CAST(REGEXP_SUBSTR(i."id_31", 'chrome ([0-9]+)', 1, 1, 'ie', 1) AS INT) < 65  THEN 'Chrome 60-64'
            WHEN TRY_CAST(REGEXP_SUBSTR(i."id_31", 'chrome ([0-9]+)', 1, 1, 'ie', 1) AS INT) >= 65 THEN 'Chrome 65+'
            ELSE 'Chrome (version unknown)'
        END
        ELSE NULL
    END AS chrome_version_bucket,

    /* Exotic browser flag (quick boolean for modeling) */
    CASE
        WHEN i."id_31" IN (
            'waterfox','cyberfox','palemoon','puffin',
            'seamonkey','iron','comodo','icedragon',
            'maxthon','aol','line'
        ) THEN 1 ELSE 0
    END AS is_exotic_browser

FROM FRAUD_DB.RAW.RAW_TRANSACTION t
LEFT JOIN FRAUD_DB.RAW.RAW_IDENTITY i ON t."TransactionID" = i."TransactionID";



-- Feature engineering for DeviceInfo: Manufacturer + Device Tier
SELECT
    t."TransactionID",

    /* Manufacturer extracted from raw string */
    CASE
        WHEN i."DeviceInfo" ILIKE '%SAMSUNG%' OR i."DeviceInfo" ILIKE 'SM-%' OR i."DeviceInfo" ILIKE 'GT-%' OR i."DeviceInfo" ILIKE 'SCH-%' THEN 'Samsung'
        WHEN i."DeviceInfo" ILIKE '%Moto%' OR i."DeviceInfo" ILIKE 'XT%'     THEN 'Motorola'
        WHEN i."DeviceInfo" ILIKE 'LG-%' OR i."DeviceInfo" ILIKE 'LGL%' OR i."DeviceInfo" ILIKE 'LGMS%' OR i."DeviceInfo" ILIKE 'LGLS%' THEN 'LG'
        WHEN i."DeviceInfo" ILIKE '%HUAWEI%' OR i."DeviceInfo" ILIKE '%Honor%' THEN 'Huawei'
        WHEN i."DeviceInfo" ILIKE '%Redmi%' OR i."DeviceInfo" ILIKE '%Xiaomi%' OR i."DeviceInfo" ILIKE 'Mi %' THEN 'Xiaomi'
        WHEN i."DeviceInfo" ILIKE '%Pixel%' OR i."DeviceInfo" ILIKE '%Nexus%'  THEN 'Google'
        WHEN i."DeviceInfo" ILIKE '%HTC%'                                    THEN 'HTC'
        WHEN i."DeviceInfo" ILIKE '%Lenovo%'                                 THEN 'Lenovo'
        WHEN i."DeviceInfo" ILIKE '%Nokia%' OR i."DeviceInfo" ILIKE 'TA-%'    THEN 'Nokia'
        WHEN i."DeviceInfo" ILIKE '%ZTE%' OR i."DeviceInfo" ILIKE '%Blade%' OR i."DeviceInfo" ILIKE 'Z%Build%' THEN 'ZTE'
        WHEN i."DeviceInfo" ILIKE '%Alcatel%' OR i."DeviceInfo" ILIKE '%ONE TOUCH%' THEN 'Alcatel'
        WHEN i."DeviceInfo" ILIKE '%BLU%'                                    THEN 'BLU'
        WHEN i."DeviceInfo" ILIKE '%Ilium%' OR i."DeviceInfo" ILIKE '%Lanix%' THEN 'Lanix'
        WHEN i."DeviceInfo" ILIKE '%Hisense%'                                THEN 'Hisense'
        WHEN i."DeviceInfo" ILIKE '%ONEPLUS%'                                THEN 'OnePlus'
        WHEN i."DeviceInfo" ILIKE '%Sony%' OR i."DeviceInfo" ILIKE 'F%Build%' OR i."DeviceInfo" ILIKE 'D%Build%' OR i."DeviceInfo" ILIKE 'E%Build%' THEN 'Sony'
        WHEN i."DeviceInfo" ILIKE '%KFASWI%' OR i."DeviceInfo" ILIKE '%KFFOWI%' OR i."DeviceInfo" ILIKE 'KF%'   THEN 'Amazon Kindle'
        WHEN i."DeviceInfo" ILIKE '%Windows%' OR i."DeviceInfo" ILIKE '%rv:%' OR i."DeviceInfo" ILIKE '%Trident%' OR i."DeviceInfo" ILIKE '%WOW64%' OR i."DeviceInfo" ILIKE '%Linux x86%' THEN 'Desktop/Non-Mobile'
        WHEN i."DeviceInfo" ILIKE '%iOS%'                                    THEN 'Apple (iOS)'
        WHEN i."DeviceInfo" IS NULL                                          THEN 'No Identity Match'
        ELSE 'Other/Unknown'
    END AS device_manufacturer,

    /* Samsung tier split (flagship S/Note vs mid J/A vs budget) */
    CASE
        WHEN i."DeviceInfo" ILIKE 'SM-G9%' OR i."DeviceInfo" ILIKE 'SM-N9%'
          OR i."DeviceInfo" ILIKE 'SAMSUNG SM-G9%' OR i."DeviceInfo" ILIKE 'SAMSUNG SM-N9%'
                                         THEN 'Samsung Flagship (S/Note)'
        WHEN i."DeviceInfo" ILIKE 'SM-A%' OR i."DeviceInfo" ILIKE 'SM-J%'
          OR i."DeviceInfo" ILIKE 'SAMSUNG SM-A%' OR i."DeviceInfo" ILIKE 'SAMSUNG SM-J%'
                                         THEN 'Samsung Mid-Range (A/J)'
        WHEN i."DeviceInfo" ILIKE 'SM-G5%' OR i."DeviceInfo" ILIKE 'SM-G3%'
          OR i."DeviceInfo" ILIKE 'SAMSUNG SM-G5%' OR i."DeviceInfo" ILIKE 'SAMSUNG SM-G3%'
                                         THEN 'Samsung Budget (G3/G5xx)'
        ELSE NULL
    END AS samsung_tier

FROM FRAUD_DB.RAW.RAW_IDENTITY i
LEFT JOIN FRAUD_DB.RAW.RAW_TRANSACTION t ON t."TransactionID" = i."TransactionID";


-- Final EDA dashboard

WITH features AS (
    SELECT
        t."TransactionID",
        t."isFraud",

        /* OS Family */
        CASE
            WHEN i."id_30" ILIKE '%windows%' THEN 'Windows'
            WHEN i."id_30" ILIKE '%mac os%' OR i."id_30" ILIKE '%mac%' THEN 'Mac'
            WHEN i."id_30" ILIKE '%ios%'     THEN 'iOS'
            WHEN i."id_30" ILIKE '%android%' THEN 'Android'
            WHEN i."id_30" ILIKE '%linux%'   THEN 'Linux'
            WHEN i."id_30" IS NULL           THEN 'No Identity Match'
            ELSE 'Other'
        END AS os_family,

        /* Browser Family */
        CASE
            WHEN i."id_31" ILIKE '%samsung browser%'              THEN 'Samsung Browser'
            WHEN i."id_31" ILIKE '%mobile safari%' OR i."id_31" ILIKE '%safari%' THEN 'Safari'
            WHEN i."id_31" ILIKE '%chrome%for android%' OR i."id_31" ILIKE '%chrome%for ios%' THEN 'Chrome Mobile'
            WHEN i."id_31" ILIKE '%chrome%'                       THEN 'Chrome'
            WHEN i."id_31" ILIKE '%firefox%'                      THEN 'Firefox'
            WHEN i."id_31" ILIKE '%edge%'                         THEN 'Edge'
            WHEN i."id_31" ILIKE '%ie%'                           THEN 'IE'
            WHEN i."id_31" ILIKE '%opera%'                        THEN 'Opera'
            WHEN i."id_31" IS NULL                                THEN 'No Identity Match'
            ELSE 'Other'
        END AS browser_family,

        /* Device Manufacturer */
        CASE
            WHEN i."DeviceInfo" ILIKE '%SAMSUNG%' OR i."DeviceInfo" ILIKE 'SM-%' THEN 'Samsung'
            WHEN i."DeviceInfo" ILIKE '%Apple%' OR i."DeviceInfo" ILIKE '%iOS%'  THEN 'Apple'
            WHEN i."DeviceInfo" ILIKE '%Huawei%' OR i."DeviceInfo" ILIKE '%Honor%' THEN 'Huawei'
            WHEN i."DeviceInfo" ILIKE '%Xiaomi%' OR i."DeviceInfo" ILIKE '%Redmi%' THEN 'Xiaomi'
            WHEN i."DeviceInfo" IS NULL THEN 'No Identity Match'
            ELSE 'Other/Unknown'
        END AS device_manufacturer,

        i."DeviceType"
    FROM FRAUD_DB.RAW.RAW_TRANSACTION t
    LEFT JOIN FRAUD_DB.RAW.RAW_IDENTITY i
      ON t."TransactionID" = i."TransactionID"
)

SELECT
    os_family,
    browser_family,
    device_manufacturer,
    "DeviceType",
    COUNT(*) AS total,
    SUM("isFraud") AS fraud_count,
    ROUND(SUM("isFraud") * 100.0 / COUNT(*), 2) AS fraud_rate_pct
FROM features
GROUP BY os_family, browser_family, device_manufacturer, "DeviceType"
ORDER BY fraud_rate_pct DESC;

/* OBSERVATIONS
Observations:

1. Missing identity linkage appears to be one of the strongest fraud indicators.

Many high-fraud segments contain "No Identity Match" across OS, browser, and manufacturer dimensions. Desktop traffic with missing identity information shows especially elevated fraud rates, suggesting that unavailable device fingerprinting or incomplete identity enrichment may correlate with suspicious activity.

2. Browser behavior appears more predictive than raw device manufacturer.

High fraud concentrations are repeatedly associated with browsers such as Opera, Chrome Mobile, and generic/unknown browser groups, while device manufacturer alone appears less consistently predictive. This suggests browser environment and identity quality may carry stronger fraud signal than hardware brand.

3. Android mobile ecosystems show elevated fraud exposure.

Several Android + Chrome and Android + Other Browser combinations show materially higher fraud rates than the dataset baseline. This may indicate emulator usage, disposable mobile environments, or lower device trust consistency within parts of the Android ecosystem.

4. High-volume medium-risk segments may be operationally more important than tiny extreme-risk groups.

For example, some Chrome Mobile and Chrome desktop segments contain very large transaction volumes with sustained elevated fraud rates. Even if their fraud percentage is lower than niche groups, their total fraud contribution is operationally significant.

5. Desktop traffic combined with missing identity information appears unusually risky.

Several desktop-based "No Identity Match" segments show elevated fraud rates, which may indicate automation environments, browser spoofing, virtual machines, or headless-browser activity.

6. Small-sample extreme fraud rates should be treated cautiously.

Some combinations show very high fraud percentages but extremely low transaction counts. Larger-volume segments provide more reliable and production-relevant fraud signals.
*/

/* Candidate fraud features flagged during EDA, to be added in the feature engineering workflow (staging → integration → model input) :-

Potential Features Identified During EDA:

- has_identity
- device_type
- browser_family
- os_family
- device_manufacturer_group
- browser_risk_group
- device_risk_score

*/

-- Analysis of Missing Values in Dataset

/*
Missing Values or NULLs in a column  are itself a predictive component for fraud detection.
Hence, they are given value -999 as sentinel instead, so that the ML model learns from the missingness, cause otherwise the model will just ignore NULLs and not learn from it the patterns.
*/

-- Count NULLs per column (run for key columns)
-- COUNT (column) keyword counts rows of column where not NULL
-- COUNT(*) counts total rows of dataset.

-- The UNION ALL just appends each result vertically, so that you can see all in one table. 

SELECT 'dist1' AS col, COUNT(*) - COUNT("dist1") AS null_count FROM RAW_TRANSACTION UNION ALL
SELECT 'dist2' AS col, COUNT(*) - COUNT("dist2") AS null_count FROM RAW_TRANSACTION UNION ALL
SELECT 'addr1' AS col, COUNT(*) - COUNT("addr1") AS null_count FROM RAW_TRANSACTION UNION ALL
SELECT 'addr2' AS col, COUNT(*) - COUNT("addr2") AS null_count FROM RAW_TRANSACTION
ORDER BY null_count DESC;

-- dist2 and dist1 column have highest NULL values.
/*
Column	NULL Count
dist2	552,913
dist1	352,271
addr1	65,706
addr2	65,706
*/

/*
dist2 mostly missing ->	unstable enrichment signal
dist1 highly sparse	-> maybe useful when present
addr columns less sparse -> more reliable geo features
*/

-- We don't know exactly what dist1 and dist2 represents. Vesta may also have randomly removed a huge chunk of these distance data to preserve anonymity and protect customers.
-- Hence, let the model learn from it is, as the data is given.

-- V columns (V1-V339) have 60-95% missing in some columns. These are very sparse columns as mentioned by author of dataset.
-- Use -999 as sentinel, NOT dropping these columns
-- Because its very painful to hardcode in SQL the NULL imputation for 339 columns, we will do Null imputation for all the V-columns in Snowpark Python before we load it into the ML model. Though we will loose explainability for this change since we don't do this imputation in sql+dbt stage

-- For all other columns such as D1-D15, C1-C14, M1-M9 etc.. .., its going to be imputed in stg_transation.sql

-- Also, In later stages, the NULL values in columns like card4 etc and many other string columns are imputated or replaced with string 'unknown' instead of numerical value -999, just to differentiate the models learning process. This will be done in later stage.
