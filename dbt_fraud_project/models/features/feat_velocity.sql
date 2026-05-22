{{ config(materialized='table', schema='FEATURES') }}

SELECT
    t.*,

    -- Card transaction count over rolling 7 days.
    -- RANGE not ROWS so it captures all transactions on same day correctly.
    COUNT(*) OVER (
        PARTITION BY card1
        ORDER BY txn_day_number
        RANGE BETWEEN 7 PRECEDING AND CURRENT ROW
    ) AS card1_txn_count_7d,

    -- Card total spend over rolling 7 days.
    SUM(TransactionAmt) OVER (
        PARTITION BY card1
        ORDER BY txn_day_number
        RANGE BETWEEN 7 PRECEDING AND CURRENT ROW
    ) AS card1_amt_sum_7d,

    -- Card average spend over rolling 30 days.
    AVG(TransactionAmt) OVER (
        PARTITION BY card1
        ORDER BY txn_day_number
        RANGE BETWEEN 30 PRECEDING AND CURRENT ROW
    ) AS card1_avg_amt_30d,

    -- Current transaction vs card 30-day rolling average.
    -- Using rolling window not full history to avoid data leakage.
    TransactionAmt / NULLIF(
        AVG(TransactionAmt) OVER (
            PARTITION BY card1
            ORDER BY txn_day_number
            RANGE BETWEEN 30 PRECEDING AND CURRENT ROW
        ), 0
    ) AS amt_to_card_avg_ratio,

    -- Same purchaser email used many times in a short window.
    COUNT(*) OVER (
        PARTITION BY p_email_clean
        ORDER BY txn_day_number
        RANGE BETWEEN 7 PRECEDING AND CURRENT ROW
    ) AS email_txn_count_7d,

    -- Pseudo customer ID: card + billing address combination.
    -- uid string kept for computing uid_txn_count_30d. Not passed to ML.
    CONCAT(
        CAST(card1 AS VARCHAR), '_', CAST(addr1_clean AS VARCHAR)
    ) AS uid,

    COUNT(*) OVER (
        PARTITION BY CONCAT(
            CAST(card1 AS VARCHAR), '_', CAST(addr1_clean AS VARCHAR)
        )
        ORDER BY txn_day_number
        RANGE BETWEEN 30 PRECEDING AND CURRENT ROW
    ) AS uid_txn_count_30d

FROM {{ ref('feat_time') }} t