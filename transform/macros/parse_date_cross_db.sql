{% macro parse_date_cross_db(column, format) %}
    {% if target is defined and target.type == 'bigquery' %}
        parse_date('{{ format }}', {{ column }})
    {% else %}
        try_strptime({{ column }}, '{{ format }}')::date
    {% endif %}
{% endmacro %}
