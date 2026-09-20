{% macro datediff_cross_db(unit, start_date, end_date) %}
    {% if target is defined and target.type == 'bigquery' %}
        date_diff({{ end_date }}, {{ start_date }}, {{ unit }})
    {% else %}
        datediff('{{ unit }}', {{ start_date }}, {{ end_date }})
    {% endif %}
{% endmacro %}
