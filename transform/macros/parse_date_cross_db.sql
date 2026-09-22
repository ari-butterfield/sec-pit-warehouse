{% macro parse_date_cross_db(column, format) %}
    {% if target is defined and target.type == 'bigquery' %}
        {# safe. prefix so a malformed date nulls out, as try_strptime does on
           duckdb, instead of failing the entire BigQuery job. #}
        safe.parse_date('{{ format }}', {{ column }})
    {% else %}
        try_strptime({{ column }}, '{{ format }}')::date
    {% endif %}
{% endmacro %}
