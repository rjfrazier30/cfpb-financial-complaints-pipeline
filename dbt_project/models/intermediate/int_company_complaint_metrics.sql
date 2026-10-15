/*
    Intermediate model: int_company_complaint_metrics
    ==================================================
    Monthly complaint metrics per company.
    Aggregates volume, response quality, and dispute rates
    so the marts layer can join without re-scanning raw rows.
*/

with complaints as (

    select * from {{ ref('stg_complaints') }}

),

monthly_metrics as (

    select
        company,
        date_trunc('month', date_received)::date      as complaint_month,

        -- Volume
        count(*)                                       as total_complaints,
        count(distinct product)                        as distinct_products,

        -- Response quality
        avg(days_to_forward)                           as avg_days_to_forward,
        median(days_to_forward)                        as median_days_to_forward,

        -- Timeliness
        sum(case when is_timely_response then 1 else 0 end)
            as timely_responses,
        round(
            timely_responses * 100.0 / nullif(total_complaints, 0), 2
        )                                              as timely_response_pct,

        -- Disputes
        sum(case when is_consumer_disputed then 1 else 0 end)
            as disputed_complaints,
        round(
            disputed_complaints * 100.0 / nullif(total_complaints, 0), 2
        )                                              as dispute_rate_pct,

        -- Narratives (consumers who opted in to share their story)
        sum(case when has_narrative then 1 else 0 end)
            as complaints_with_narrative,

        -- Submission channels
        count(distinct submission_channel)             as distinct_channels

    from complaints
    group by 1, 2

)

select * from monthly_metrics
