/*
    Staging model: stg_complaints
    ==============================
    Cleans and standardizes raw CFPB complaint data.
    - Casts types explicitly
    - Trims whitespace
    - Standardizes boolean-like fields
    - Adds a response time calculation
*/

with source as (

    select * from {{ source('raw', 'raw_complaints') }}

),

cleaned as (

    select
        complaint_id,

        -- Dates
        date_received,
        date_sent_to_company,
        datediff('day', date_received, date_sent_to_company) as days_to_forward,

        -- Product categorization
        trim(upper(product))                         as product,
        trim(upper(sub_product))                     as sub_product,

        -- Issue details
        trim(issue)                                  as issue,
        trim(sub_issue)                              as sub_issue,

        -- Narrative (may be null if consumer didn't consent)
        consumer_complaint_narrative,
        case
            when consumer_complaint_narrative is not null
                 and length(consumer_complaint_narrative) > 0
            then true
            else false
        end                                          as has_narrative,

        -- Company info
        trim(upper(company))                         as company,
        trim(company_public_response)                as company_public_response,
        trim(company_response)                       as company_response,

        -- Consumer info
        trim(upper(state))                           as state_code,
        left(trim(zip_code), 5)                      as zip_code_5,
        trim(tags)                                   as consumer_tags,
        trim(submitted_via)                          as submission_channel,

        -- Boolean standardization
        case
            when trim(lower(timely_response)) = 'yes' then true
            when trim(lower(timely_response)) = 'no'  then false
            else null
        end                                          as is_timely_response,

        case
            when trim(lower(consumer_disputed)) = 'yes' then true
            when trim(lower(consumer_disputed)) = 'no'  then false
            else null
        end                                          as is_consumer_disputed,

        -- Metadata
        _loaded_at

    from source

)

select * from cleaned
