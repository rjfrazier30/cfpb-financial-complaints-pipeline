/*
    Macro: safe_rate
    =================
    Calculates a percentage rate with null-safe division.
    Reusable across models to avoid copy-paste of the
    CASE WHEN / NULLIF pattern.

    Usage:
        {{ safe_rate('is_timely_response', 'true') }}
        {{ safe_rate('is_consumer_disputed', 'true', 1) }}
*/

{% macro safe_rate(column, condition_value='true', decimal_places=2) %}
    round(
        sum(case when {{ column }} = {{ condition_value }} then 1 else 0 end)
        * 100.0 / nullif(count(*), 0),
        {{ decimal_places }}
    )
{% endmacro %}
