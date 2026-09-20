{% macro safe_cast_cross_db(column, type) %}
  {% if target.type == 'bigquery' %}
    safe_cast({{ column }} as {{ type }})
  {% else %}
    try_cast({{ column }} as {{ type }})
  {% endif %}
{% endmacro %}
