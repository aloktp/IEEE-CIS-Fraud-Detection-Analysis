-- id_30 = OS field. id_31 = browser field. DeviceInfo = hardware model string.

{{ config(materialized='table', schema='STAGING') }}

SELECT
    "TransactionID"                                      AS TransactionID,
    COALESCE("DeviceType", 'unknown')                    AS device_type,
    "DeviceInfo"                                         AS DeviceInfo,

    -- OS FAMILY (from id_30 — the correct OS column, not DeviceInfo)
    CASE
        WHEN "id_30" ILIKE '%windows%'                   THEN 'windows'
        WHEN "id_30" ILIKE '%mac os%'                    THEN 'mac'
        WHEN "id_30" ILIKE '%ios%'                       THEN 'ios'
        WHEN "id_30" ILIKE '%android%'                   THEN 'android'
        WHEN "id_30" ILIKE '%linux%'                     THEN 'linux'
        WHEN "id_30" IS NULL                             THEN 'unknown'
        ELSE 'other'
    END AS os_group,

    -- OS VERSION GROUP (old OS = unpatched = higher fraud risk)
    CASE
        WHEN "id_30" ILIKE '%windows 10%'                THEN 'windows_10'
        WHEN "id_30" ILIKE '%windows 7%'                 THEN 'windows_7_old'
        WHEN "id_30" ILIKE '%windows 8%'                 THEN 'windows_8'
        WHEN "id_30" ILIKE '%windows vista%'
          OR "id_30" ILIKE '%windows xp%'                THEN 'windows_very_old'
        WHEN "id_30" ILIKE '%ios 11%'                    THEN 'ios_11'
        WHEN "id_30" ILIKE '%ios 10%'                    THEN 'ios_10'
        WHEN "id_30" ILIKE '%ios 9%'                     THEN 'ios_9_old'
        WHEN "id_30" ILIKE '%android 8%'                 THEN 'android_8'
        WHEN "id_30" ILIKE '%android 7%'                 THEN 'android_7'
        WHEN "id_30" ILIKE '%android 6%'                 THEN 'android_6'
        WHEN "id_30" ILIKE '%android 5%'                 THEN 'android_5_old'
        WHEN "id_30" ILIKE '%android 4%'                 THEN 'android_4_very_old'
        WHEN "id_30" ILIKE '%mac os x 10_13%'
          OR "id_30" ILIKE '%mac os x 10.13%'            THEN 'macos_high_sierra'
        WHEN "id_30" ILIKE '%mac os x 10_12%'
          OR "id_30" ILIKE '%mac os x 10.12%'            THEN 'macos_sierra'
        WHEN "id_30" ILIKE '%mac os x 10_11%'
          OR "id_30" ILIKE '%mac os x 10.11%'            THEN 'macos_el_capitan'
        WHEN "id_30" ILIKE '%mac os%'                    THEN 'macos_old'
        WHEN "id_30" ILIKE '%linux%'                     THEN 'linux'
        WHEN "id_30" IS NULL                             THEN 'unknown'
        ELSE 'other'
    END AS os_version_group,

    -- BROWSER FAMILY (from id_31 — the correct browser column)
    CASE
        WHEN "id_31" ILIKE '%samsung browser%'           THEN 'samsung_browser'
        WHEN "id_31" ILIKE '%mobile safari%'
          OR ("id_31" ILIKE '%safari%'
          AND "id_31" NOT ILIKE '%chrome%')               THEN 'safari'
        WHEN "id_31" ILIKE '%chrome%for android%'
          OR "id_31" ILIKE '%chrome%for ios%'             THEN 'chrome_mobile'
        WHEN "id_31" ILIKE '%chrome%'                    THEN 'chrome'
        WHEN "id_31" ILIKE '%firefox%'                   THEN 'firefox'
        WHEN "id_31" ILIKE '%edge%'                      THEN 'edge'
        WHEN "id_31" ILIKE '%ie%'                        THEN 'ie'
        WHEN "id_31" ILIKE '%opera%'                     THEN 'opera'
        WHEN "id_31" ILIKE '%android webview%'
          OR "id_31" ILIKE '%uiwebview%'                 THEN 'webview'
        WHEN "id_31" ILIKE '%silk%'                      THEN 'silk'
        WHEN "id_31" IN ('waterfox','cyberfox','palemoon','puffin',
                         'seamonkey','iron','comodo','icedragon',
                         'maxthon','aol','line')          THEN 'exotic'
        WHEN "id_31" IS NULL                             THEN 'unknown'
        ELSE 'other'
    END AS browser_family,

    -- CHROME VERSION BUCKET (old Chrome = unpatched = higher fraud risk)
    CASE
        WHEN "id_31" ILIKE '%chrome%'
        THEN CASE
            WHEN TRY_CAST(
                REGEXP_SUBSTR("id_31", 'chrome ([0-9]+)', 1, 1, 'ie', 1)
                AS INT) < 55                             THEN 'chrome_old'
            WHEN TRY_CAST(
                REGEXP_SUBSTR("id_31", 'chrome ([0-9]+)', 1, 1, 'ie', 1)
                AS INT) < 60                             THEN 'chrome_55_59'
            WHEN TRY_CAST(
                REGEXP_SUBSTR("id_31", 'chrome ([0-9]+)', 1, 1, 'ie', 1)
                AS INT) < 65                             THEN 'chrome_60_64'
            WHEN TRY_CAST(
                REGEXP_SUBSTR("id_31", 'chrome ([0-9]+)', 1, 1, 'ie', 1)
                AS INT) >= 65                            THEN 'chrome_65_plus'
            ELSE 'chrome_unknown'
        END
        ELSE NULL
    END AS chrome_version_bucket,

    -- Exotic browser binary flag. Rare browser. No patch updates. Security vulnerable.
    CASE
        WHEN "id_31" IN ('waterfox','cyberfox','palemoon','puffin',
                         'seamonkey','iron','comodo','icedragon',
                         'maxthon','aol','line')          THEN 1
        ELSE 0
    END AS is_exotic_browser,

    -- DEVICE MANUFACTURER (from DeviceInfo hardware string)
    CASE
        WHEN "DeviceInfo" ILIKE '%SAMSUNG%'
          OR "DeviceInfo" ILIKE 'SM-%'
          OR "DeviceInfo" ILIKE 'GT-%'
          OR "DeviceInfo" ILIKE 'SCH-%'                  THEN 'samsung'
        WHEN "DeviceInfo" ILIKE '%Moto%'
          OR "DeviceInfo" ILIKE 'XT%'                    THEN 'motorola'
        WHEN "DeviceInfo" ILIKE 'LG-%'
          OR "DeviceInfo" ILIKE 'LGL%'
          OR "DeviceInfo" ILIKE 'LGMS%'
          OR "DeviceInfo" ILIKE 'LGLS%'                  THEN 'lg'
        WHEN "DeviceInfo" ILIKE '%HUAWEI%'
          OR "DeviceInfo" ILIKE '%Honor%'                THEN 'huawei'
        WHEN "DeviceInfo" ILIKE '%Redmi%'
          OR "DeviceInfo" ILIKE '%Xiaomi%'
          OR "DeviceInfo" ILIKE 'Mi %'                   THEN 'xiaomi'
        WHEN "DeviceInfo" ILIKE '%Pixel%'
          OR "DeviceInfo" ILIKE '%Nexus%'                THEN 'google'
        WHEN "DeviceInfo" ILIKE '%HTC%'                  THEN 'htc'
        WHEN "DeviceInfo" ILIKE '%Lenovo%'               THEN 'lenovo'
        WHEN "DeviceInfo" ILIKE 'TA-%'
          OR "DeviceInfo" ILIKE '%Nokia%'                THEN 'nokia'
        WHEN "DeviceInfo" ILIKE '%ZTE%'
          OR "DeviceInfo" ILIKE '%Blade%'                THEN 'zte'
        WHEN "DeviceInfo" ILIKE '%Alcatel%'
          OR "DeviceInfo" ILIKE '%ONE TOUCH%'            THEN 'alcatel'
        WHEN "DeviceInfo" ILIKE '%BLU%'                  THEN 'blu'
        WHEN "DeviceInfo" ILIKE '%Ilium%'
          OR "DeviceInfo" ILIKE '%Lanix%'                THEN 'lanix'
        WHEN "DeviceInfo" ILIKE '%KF%'                   THEN 'amazon_kindle'
        WHEN "DeviceInfo" ILIKE '%Windows%'
          OR "DeviceInfo" ILIKE '%rv:%'
          OR "DeviceInfo" ILIKE '%Trident%'
          OR "DeviceInfo" ILIKE '%WOW64%'
          OR "DeviceInfo" ILIKE '%Linux x86%'            THEN 'desktop_non_mobile'
        WHEN "DeviceInfo" IS NULL                        THEN 'unknown'
        ELSE 'other'
    END AS device_manufacturer,

    -- Samsung tier (flagship vs mid-range vs budget)
    CASE
        WHEN "DeviceInfo" ILIKE 'SM-G9%'
          OR "DeviceInfo" ILIKE 'SM-N9%'
          OR "DeviceInfo" ILIKE 'SAMSUNG SM-G9%'
          OR "DeviceInfo" ILIKE 'SAMSUNG SM-N9%'         THEN 'samsung_flagship'
        WHEN "DeviceInfo" ILIKE 'SM-A%'
          OR "DeviceInfo" ILIKE 'SM-J%'
          OR "DeviceInfo" ILIKE 'SAMSUNG SM-A%'
          OR "DeviceInfo" ILIKE 'SAMSUNG SM-J%'          THEN 'samsung_mid'
        WHEN "DeviceInfo" ILIKE 'SM-G5%'
          OR "DeviceInfo" ILIKE 'SM-G3%'                 THEN 'samsung_budget'
        ELSE NULL
    END AS samsung_tier,

    -- Old Android on budget device = compounding fraud risk signal
    CASE
        WHEN ("id_30" ILIKE '%android 4%' OR "id_30" ILIKE '%android 5%')
         AND ("DeviceInfo" ILIKE '%Nokia%'
              OR "DeviceInfo" ILIKE '%ZTE%'
              OR "DeviceInfo" ILIKE '%BLU%'
              OR "DeviceInfo" ILIKE '%Alcatel%'
              OR "DeviceInfo" ILIKE '%Lanix%')            THEN 1
        ELSE 0
    END AS is_old_android_budget_device,

    -- Both OS and browser NULL = likely bot or scraper
    CASE
        WHEN "id_30" IS NULL AND "id_31" IS NULL         THEN 1
        ELSE 0
    END AS no_browser_os_signal,

    -- IDENTITY NUMERIC FEATURES id_01-id_11
    COALESCE("id_01", -999)                              AS id_01,
    COALESCE("id_02", -999)                              AS id_02,
    COALESCE("id_03", -999)                              AS id_03,
    COALESCE("id_04", -999)                              AS id_04,
    COALESCE("id_05", -999)                              AS id_05,
    COALESCE("id_06", -999)                              AS id_06,
    COALESCE("id_07", -999)                              AS id_07,
    COALESCE("id_08", -999)                              AS id_08,
    COALESCE("id_09", -999)                              AS id_09,
    COALESCE("id_10", -999)                              AS id_10,
    COALESCE("id_11", -999)                              AS id_11,

    -- id_12: TEXT -> categorical
    COALESCE("id_12", 'unknown')                         AS id_12,

    -- id_13: NUMBER (not categorical as initially assumed)
    COALESCE("id_13", -999)                              AS id_13,

    -- id_14: NUMBER
    COALESCE("id_14", -999)                              AS id_14,

    -- id_15: TEXT -> categorical (Found / New / Unknown)
    COALESCE("id_15", 'unknown')                         AS id_15,

    -- id_16: TEXT -> categorical (Found / NotFound)
    COALESCE("id_16", 'unknown')                         AS id_16,

    -- IDENTITY NUMERIC id_17-id_22
    COALESCE("id_17", -999)                              AS id_17,
    COALESCE("id_18", -999)                              AS id_18,
    COALESCE("id_19", -999)                              AS id_19,
    COALESCE("id_20", -999)                              AS id_20,
    COALESCE("id_21", -999)                              AS id_21,
    COALESCE("id_22", -999)                              AS id_22,

    -- id_23: TEXT -> categorical (IP_PROXY:HIDDEN / ANONYMOUS / TRANSPARENT)
    -- Strong fraud signal — hiding IP is suspicious behaviour.
    COALESCE("id_23", 'unknown')                         AS id_23,

    -- IDENTITY NUMERIC id_24-id_26
    COALESCE("id_24", -999)                              AS id_24,
    COALESCE("id_25", -999)                              AS id_25,
    COALESCE("id_26", -999)                              AS id_26,

    -- id_27: TEXT -> categorical
    COALESCE("id_27", 'unknown')                         AS id_27,

    -- id_28: TEXT -> categorical (FOUND / NEW)
    COALESCE("id_28", 'unknown')                         AS id_28,

    -- id_29: TEXT -> categorical (FOUND / NOTFOUND)
    COALESCE("id_29", 'unknown')                         AS id_29,

    -- id_32: NUMBER
    COALESCE("id_32", -999)                              AS id_32,

    -- id_33: TEXT screen resolution e.g. 1920x1080
    -- Split into width and height so model learns from each dimension separately.
    COALESCE(
        TRY_CAST(SPLIT_PART("id_33", 'x', 1) AS NUMBER), -999
    )                                                    AS screen_width,
    COALESCE(
        TRY_CAST(SPLIT_PART("id_33", 'x', 2) AS NUMBER), -999
    )                                                    AS screen_height,

    -- id_34: TEXT match_status:0 / match_status:1 / match_status:-1 / match_status:2
    -- Ordinal values — extract integer so model treats them as ordered.
    COALESCE(
        TRY_CAST(REPLACE("id_34", 'match_status:', '') AS NUMBER), -999
    )                                                    AS id_34_match_status,

    -- id_35-id_38: BOOLEAN type -> cast to integer 1/0
    -- IFF(boolean_col, true_result, false_result) is Snowflake native function.
    IFF("id_35", 1, 0)                                   AS id_35_flag,
    IFF("id_36", 1, 0)                                   AS id_36_flag,
    IFF("id_37", 1, 0)                                   AS id_37_flag,
    IFF("id_38", 1, 0)                                   AS id_38_flag

FROM {{ source('raw', 'RAW_IDENTITY') }}
