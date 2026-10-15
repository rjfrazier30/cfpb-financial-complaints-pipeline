/*
    Mart model: fct_complaints
    ===========================
    Fact table — one row per complaint.
    The primary analytics table for dashboards and ad-hoc queries.
    Includes all cleaned fields plus derived metrics from staging.
*/

with complaints as (

    select * from {{ ref('stg_complaints') }}

),

final as (

    select
        -- Keys
        complaint_id,

        -- Dates (for time-series analysis)
        date_received,
        date_sent_to_company,
        date_trunc('month', date_received)::date   as complaint_month,
        date_trunc('quarter', date_received)::date  as complaint_quarter,
        year(date_received)                         as complaint_year,
        dayofweek(date_received)                    as complaint_dow,

        -- Dimensions
        company,
        product,
        sub_product,
        issue,
        sub_issue,
        state_code,
        zip_code_5,
        submission_channel,
        consumer_tags,
        company_response,
        company_public_response,

        -- Measures
        days_to_forward,
        has_narrative,
        is_timely_response,
        is_consumer_disputed,

        -- Text (for NLP if desired)
        consumer_complaint_narrative,

        -- Metadata
        _loaded_at

    from complaints

)

select * from final
