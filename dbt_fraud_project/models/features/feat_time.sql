{{ config(materialized='table', schema='FEATURES') }}

SELECT
    *,

    -- Overnight flag (fraud spikes in early hours 0-5am)
    CASE
        WHEN txn_hour BETWEEN 0 AND 5               THEN 1
        ELSE 0
    END AS is_night_transaction,

    -- For dashboard use only. Not used in ML.
    CASE
        WHEN txn_hour BETWEEN 0 AND 5               THEN 'high_risk_hours'
        WHEN txn_hour BETWEEN 6 AND 18              THEN 'normal_hours'
        ELSE 'evening_hours'
    END AS txn_time_bucket

FROM {{ ref('int_joined') }}