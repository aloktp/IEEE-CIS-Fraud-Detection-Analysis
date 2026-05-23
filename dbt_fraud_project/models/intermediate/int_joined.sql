{{ config(materialized='table', schema='STAGING') }}

-- LEFT JOIN: all transactions kept even if no identity match.
-- Missing identity is itself a fraud signal, captured in has_identity.
-- COALESCE applied at join level for the 446,307 rows with no identity match.
-- These rows have has_identity=0 so the model knows defaults are not real values.

SELECT
    t.*,

    -- Categorical identity columns: NULL from no-match -> 'unknown'
    COALESCE(i.device_type, 'unknown')               AS device_type,
    COALESCE(i.os_group, 'unknown')                  AS os_group,
    COALESCE(i.os_version_group, 'unknown')          AS os_version_group,
    COALESCE(i.browser_family, 'unknown')            AS browser_family,
    COALESCE(i.chrome_version_bucket, 'unknown')     AS chrome_version_bucket,
    COALESCE(i.device_manufacturer, 'unknown')       AS device_manufacturer,
    COALESCE(i.samsung_tier, 'unknown')              AS samsung_tier,

    -- Binary flag columns: NULL from no-match -> 0
    COALESCE(i.is_exotic_browser, 0)                 AS is_exotic_browser,
    COALESCE(i.is_old_android_budget_device, 0)      AS is_old_android_budget_device,
    COALESCE(i.no_browser_os_signal, 0)              AS no_browser_os_signal,

    -- Identity numeric id_01-id_11: NULL from no-match -> -999
    COALESCE(i.id_01, -999)                          AS id_01,
    COALESCE(i.id_02, -999)                          AS id_02,
    COALESCE(i.id_03, -999)                          AS id_03,
    COALESCE(i.id_04, -999)                          AS id_04,
    COALESCE(i.id_05, -999)                          AS id_05,
    COALESCE(i.id_06, -999)                          AS id_06,
    COALESCE(i.id_07, -999)                          AS id_07,
    COALESCE(i.id_08, -999)                          AS id_08,
    COALESCE(i.id_09, -999)                          AS id_09,
    COALESCE(i.id_10, -999)                          AS id_10,
    COALESCE(i.id_11, -999)                          AS id_11,

    -- Identity categorical id_12, id_15, id_16, id_23, id_27, id_28, id_29
    COALESCE(i.id_12, 'unknown')                     AS id_12,
    COALESCE(i.id_15, 'unknown')                     AS id_15,
    COALESCE(i.id_16, 'unknown')                     AS id_16,
    COALESCE(i.id_23, 'unknown')                     AS id_23,
    COALESCE(i.id_27, 'unknown')                     AS id_27,
    COALESCE(i.id_28, 'unknown')                     AS id_28,
    COALESCE(i.id_29, 'unknown')                     AS id_29,

    -- Identity numeric id_13, id_14, id_17-id_22, id_24-id_26, id_32
    COALESCE(i.id_13, -999)                          AS id_13,
    COALESCE(i.id_14, -999)                          AS id_14,
    COALESCE(i.id_17, -999)                          AS id_17,
    COALESCE(i.id_18, -999)                          AS id_18,
    COALESCE(i.id_19, -999)                          AS id_19,
    COALESCE(i.id_20, -999)                          AS id_20,
    COALESCE(i.id_21, -999)                          AS id_21,
    COALESCE(i.id_22, -999)                          AS id_22,
    COALESCE(i.id_24, -999)                          AS id_24,
    COALESCE(i.id_25, -999)                          AS id_25,
    COALESCE(i.id_26, -999)                          AS id_26,
    COALESCE(i.id_32, -999)                          AS id_32,

    -- Screen resolution split from id_33
    COALESCE(i.screen_width, -999)                   AS screen_width,
    COALESCE(i.screen_height, -999)                  AS screen_height,

    -- Match status extracted from id_34
    COALESCE(i.id_34_match_status, -999)             AS id_34_match_status,

    -- Boolean flags id_35-id_38: NULL from no-match -> 0
    COALESCE(i.id_35_flag, 0)                        AS id_35_flag,
    COALESCE(i.id_36_flag, 0)                        AS id_36_flag,
    COALESCE(i.id_37_flag, 0)                        AS id_37_flag,
    COALESCE(i.id_38_flag, 0)                        AS id_38_flag,

    -- has_identity: 0 means no identity row existed at all
    CASE
        WHEN i.TransactionID IS NOT NULL               THEN 1
        ELSE 0
    END AS has_identity

FROM {{ ref('stg_transaction') }} t
LEFT JOIN {{ ref('stg_identity') }} i
    ON t.TransactionID = i.TransactionID