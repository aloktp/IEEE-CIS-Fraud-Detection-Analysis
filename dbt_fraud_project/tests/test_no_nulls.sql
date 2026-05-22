-- dbt fails the run if this query returns any rows.

SELECT *
FROM {{ ref('feat_final') }}
WHERE
    -- Core identifiers
    TransactionID          IS NULL
    OR isFraud             IS NULL

    -- Time (these are derived from TransactionDT so should never be null)
    OR txn_hour            IS NULL
    OR txn_day_of_week     IS NULL
    OR txn_day_number      IS NULL

    -- Amount (log transform would fail silently if TransactionAmt was 0 or negative)
    OR log_txn_amt         IS NULL
    OR TransactionAmt      IS NULL

    -- Card (used in velocity window partitions — null here breaks grouping)
    OR card1               IS NULL

    -- Velocity features (null means window function failed)
    OR card1_txn_count_7d  IS NULL
    OR card1_amt_sum_7d    IS NULL
    OR email_txn_count_7d  IS NULL
    OR uid_txn_count_30d   IS NULL

    -- Engineered flags that should always resolve to 0 or 1
    OR is_night_transaction        IS NULL
    OR is_exotic_browser           IS NULL
    OR no_browser_os_signal        IS NULL
    OR is_old_android_budget_device IS NULL
    OR has_identity                IS NULL