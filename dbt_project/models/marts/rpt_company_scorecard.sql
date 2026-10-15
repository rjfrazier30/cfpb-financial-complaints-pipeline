/*
    Mart model: rpt_company_scorecard
    ==================================
    Interview-ready report: side-by-side comparison of target
    companies on key consumer complaint KPIs.

    This is the model you'd walk through in an interview:
    "I built a pipeline that compares how Capital One, Navy Federal,
     and other major financial companies handle consumer complaints."
*/

with company_dim as (

    select * from {{ ref('dim_companies') }}

),

recent_trend as (

    select
        company,
        total_complaints                                as recent_complaints,
        timely_response_pct                             as recent_timely_pct,
        dispute_rate_pct                                as recent_dispute_pct
    from {{ ref('int_company_complaint_metrics') }}
    where complaint_month >= dateadd('month', -12, current_date())

),

recent_agg as (

    select
        company,
        sum(recent_complaints)                          as last_12mo_complaints,
        round(avg(recent_timely_pct), 2)                as last_12mo_timely_pct,
        round(avg(recent_dispute_pct), 2)               as last_12mo_dispute_pct
    from recent_trend
    group by 1

),

scorecard as (

    select
        c.company,

        -- Lifetime metrics
        c.total_complaints,
        c.first_complaint_date,
        c.latest_complaint_date,
        c.distinct_products,
        c.states_with_complaints,

        -- Response quality (lifetime)
        c.avg_days_to_forward,
        c.median_days_to_forward,
        c.timely_response_pct,
        c.dispute_rate_pct,
        c.narrative_share_pct,

        -- Recent performance (last 12 months)
        r.last_12mo_complaints,
        r.last_12mo_timely_pct,
        r.last_12mo_dispute_pct,

        -- Trend indicator: improving or declining?
        case
            when r.last_12mo_timely_pct > c.timely_response_pct
            then 'IMPROVING'
            when r.last_12mo_timely_pct < c.timely_response_pct
            then 'DECLINING'
            else 'STABLE'
        end                                             as timeliness_trend,

        case
            when r.last_12mo_dispute_pct < c.dispute_rate_pct
            then 'IMPROVING'
            when r.last_12mo_dispute_pct > c.dispute_rate_pct
            then 'DECLINING'
            else 'STABLE'
        end                                             as dispute_trend,

        c.primary_channel

    from company_dim c
    left join recent_agg r on c.company = r.company

)

select * from scorecard
order by total_complaints desc
