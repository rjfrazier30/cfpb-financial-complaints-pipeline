/*
    Intermediate model: int_product_complaint_trends
    =================================================
    Monthly complaint trends by product category.
    Shows which financial products generate the most consumer
    friction — a key insight for the target companies.
*/

with complaints as (

    select * from {{ ref('stg_complaints') }}

),

product_trends as (

    select
        product,
        sub_product,
        date_trunc('month', date_received)::date       as complaint_month,

        -- Volume
        count(*)                                        as total_complaints,

        -- Top issues
        mode(issue)                                     as most_common_issue,

        -- Company response patterns
        mode(company_response)                          as most_common_response,

        -- Timeliness
        round(
            sum(case when is_timely_response then 1 else 0 end)
            * 100.0 / nullif(count(*), 0), 2
        )                                               as timely_response_pct,

        -- Dispute rates
        round(
            sum(case when is_consumer_disputed then 1 else 0 end)
            * 100.0 / nullif(count(*), 0), 2
        )                                               as dispute_rate_pct,

        -- Geographic spread
        count(distinct state_code)                      as states_affected

    from complaints
    group by 1, 2, 3

)

select * from product_trends
