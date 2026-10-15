/*
    Mart model: dim_companies
    ==========================
    Company dimension table.
    One row per company with lifetime summary statistics.
    Perfect for comparing target companies side by side.
*/

with complaints as (

    select * from {{ ref('stg_complaints') }}

),

company_stats as (

    select
        company,

        -- Lifetime volume
        count(*)                                        as total_complaints,
        min(date_received)                              as first_complaint_date,
        max(date_received)                              as latest_complaint_date,
        datediff('day', first_complaint_date, latest_complaint_date)
            as active_days,

        -- Products
        count(distinct product)                         as distinct_products,
        count(distinct sub_product)                     as distinct_sub_products,

        -- Issues
        count(distinct issue)                           as distinct_issues,

        -- Geography
        count(distinct state_code)                      as states_with_complaints,

        -- Response quality
        round(avg(days_to_forward), 2)                  as avg_days_to_forward,
        round(median(days_to_forward), 2)               as median_days_to_forward,

        round(
            sum(case when is_timely_response then 1 else 0 end)
            * 100.0 / nullif(count(*), 0), 2
        )                                               as timely_response_pct,

        round(
            sum(case when is_consumer_disputed then 1 else 0 end)
            * 100.0 / nullif(count(*), 0), 2
        )                                               as dispute_rate_pct,

        -- Narratives
        round(
            sum(case when has_narrative then 1 else 0 end)
            * 100.0 / nullif(count(*), 0), 2
        )                                               as narrative_share_pct,

        -- Submission channels
        count(distinct submission_channel)              as distinct_channels,
        mode(submission_channel)                        as primary_channel

    from complaints
    group by 1

)

select * from company_stats
