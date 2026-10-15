/*
    Mart model: dim_products
    =========================
    Product dimension table.
    One row per product/sub-product combination with
    aggregate complaint patterns.
*/

with complaints as (

    select * from {{ ref('stg_complaints') }}

),

product_stats as (

    select
        product,
        sub_product,

        -- Volume
        count(*)                                        as total_complaints,
        count(distinct company)                         as companies_with_complaints,

        -- Top issue for this product
        mode(issue)                                     as most_common_issue,

        -- Response patterns
        round(avg(days_to_forward), 2)                  as avg_days_to_forward,
        round(
            sum(case when is_timely_response then 1 else 0 end)
            * 100.0 / nullif(count(*), 0), 2
        )                                               as timely_response_pct,
        round(
            sum(case when is_consumer_disputed then 1 else 0 end)
            * 100.0 / nullif(count(*), 0), 2
        )                                               as dispute_rate_pct,

        -- Most common resolution
        mode(company_response)                          as most_common_response,

        -- Date range
        min(date_received)                              as first_complaint_date,
        max(date_received)                              as latest_complaint_date

    from complaints
    group by 1, 2

)

select * from product_stats
