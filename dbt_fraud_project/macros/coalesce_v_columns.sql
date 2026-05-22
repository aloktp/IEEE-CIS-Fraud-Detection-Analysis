-- This macro will be used in stg_tansaction.sql {{ coalesce_v_columns("RAW", "RAW_TRANSACTION") }} to coalesce all columns from V1 to V394 without having to hardcode coalescing for each V column one by one

{% macro coalesce_v_columns(source_schema, source_table) %}

    {% set v_cols_query %}
        SELECT COLUMN_NAME
        FROM FRAUD_DB.INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = '{{ source_schema }}'
          AND TABLE_NAME   = '{{ source_table }}'
          AND LEFT(COLUMN_NAME, 1) = 'V'
          AND TRY_CAST(SUBSTRING(COLUMN_NAME, 2) AS INTEGER) IS NOT NULL
        ORDER BY ORDINAL_POSITION
    {% endset %}

    {% if execute %}
        {% set results = run_query(v_cols_query) %}
        {% for row in results %}
            COALESCE("{{ row[0] }}", -999) AS {{ row[0] }}
            {%- if not loop.last %},{% endif %}
        {% endfor %}
    {% endif %}

{% endmacro %}