/*
    Intermediate model: int_response_time_analysis
    ================================================
    Analyzes company response times and resolution patterns.
    Great for showing interviewer-ready insights about
    how target companies handle consumer complaints.
*/

with complaints as (

    select * from {{ ref('stg_complaints') }}

),

response_analysis as (

    select
        company,
        company_response,
        date_trunc('quarter', date_received)::date     as complaint_quarter,

        count(*)                                        as complaint_count,

        -- Response time distribution
        avg(days_to_forward)                            as avg_days_to_forward,
        min(days_to_forward)                            as min_days_to_forward,
        max(days_to_forward)                            as max_days_to_forward,
        percentile_cont(0.50) within group (order by days_to_forward)
            as p50_days_to_forward,
        percentile_cont(0.90) within group (order by days_to_forward)
            as p90_days_to_forward,
        percentile_cont(0.95) within group (order by days_to_forward)
            as p95_days_to_forward,

        -- Resolution outcomes
        round(
            sum(case when is_timely_response then 1 else 0 end)
            * 100.0 / nullif(count(*), 0), 2
        )                                               as timely_pct,
        round(
            sum(case when is_consumer_disputed then 1 else 0 end)
            * 100.0 / nullif(count(*), 0), 2
        )                                               as dispute_pct,

        -- Narrative opt-in (higher = more frustrated consumers)
        round(
            sum(case when has_narrative then 1 else 0 end)
            * 100.0 / nullif(count(*), 0), 2
        )                                               as narrative_pct

    from complaints
    where days_to_forward is not null
    group by 1, 2, 3

)

select * from response_analysis
