-- Canonical ML-ready table. ML reads only this. Dashboard reads this + PREDICTIONS.
-- V1-V339 flow through via upstream SELECT *.
-- Remaining nulls handled by df.fillna(-999) in fraud_ml.py.

{{ config(materialized='table', schema='FEATURES') }}

SELECT
    TransactionID,
    isFraud,

    -- Time
    txn_hour,
    txn_day_of_week,
    txn_day_number,                  -- kept for ordering reference, not passed to ML
    is_night_transaction,
    txn_time_bucket,                 -- kept for dashboard, not passed to ML
    -- is_weekend removed: no clear weekend pattern found in day_mod analysis

    -- Amount
    TransactionAmt,                  -- kept for dashboard, not passed to ML
    log_txn_amt,
    amt_decimal_part,

    -- Product
    ProductCD,

    -- Card
    card1, card2, card3,
    card4_clean, card5, card6_clean,

    -- Address and distance
    addr1_clean, addr2_clean,
    dist1_clean, dist2_clean,

    -- Email
    p_email_clean,                   -- kept for dashboard, not passed to ML
    r_email_clean,                   -- kept for dashboard, not passed to ML
    p_email_group,
    r_email_group,

    -- Match flags
    -- m4_clean replaces m4_match: M4 has M0/M1/M2/NULL not T/F
    m1_flag, m2_flag, m3_flag, m4_clean,
    m5_flag, m6_flag, m7_flag, m8_flag, m9_flag,

    -- Count columns C1-C14
    C1,  C2,  C3,  C4,  C5,  C6,  C7,
    C8,  C9,  C10, C11, C12, C13, C14,

    -- Time-gap columns D1-D15
    -- D1 kept as-is (D1_normalised was removed, stg_transaction outputs plain D1)
    D1,
    D2,  D3,  D4,  D5,  D6,  D7,  D8,
    D9,  D10, D11, D12, D13, D14, D15,

    -- Device and identity
    device_type,
    os_group,
    os_version_group,
    browser_family,
    chrome_version_bucket,
    is_exotic_browser,
    device_manufacturer,
    samsung_tier,
    no_browser_os_signal,
    is_old_android_budget_device,
    has_identity,

    -- Identity numeric id_01-id_11
    id_01, id_02, id_03, id_04, id_05,
    id_06, id_07, id_08, id_09, id_10, id_11,

    -- Identity categorical id_12, id_15, id_16
    id_12, id_15, id_16,

    -- Identity numeric id_13, id_14
    id_13, id_14,

    -- Identity numeric id_17-id_22, id_24-id_26
    id_17, id_18, id_19, id_20, id_21, id_22,
    id_24, id_25, id_26,

    -- Identity categorical id_23 (IP proxy type)
    id_23,

    -- Identity categorical id_27
    id_27,

    -- Identity categorical id_28-id_29
    id_28, id_29,

    -- Identity numeric id_32
    id_32,

    -- Screen resolution split from id_33
    screen_width,
    screen_height,

    -- Match status extracted from id_34 (ordinal integer)
    id_34_match_status,

    -- Identity boolean flags id_35-id_38
    id_35_flag, id_36_flag, id_37_flag, id_38_flag,

    -- Velocity
    card1_txn_count_7d,
    card1_amt_sum_7d,
    card1_avg_amt_30d,
    amt_to_card_avg_ratio,
    email_txn_count_7d,
    uid,                             -- kept for reference, not passed to ML
    uid_txn_count_30d

    -- V1-V339 also present (inherited via upstream SELECT *)

FROM {{ ref('feat_velocity') }}
