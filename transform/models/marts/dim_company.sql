with submissions as (
    select * from {{ ref('stg_sec__submissions') }}
),

-- Type 1: current attributes only, no history. Resolved with the same rule as
-- int_facts__authoritative so a company's descriptive attributes and its facts
-- never disagree about which filing is the current one. SCD2 is v2 feature.
current_attributes as (
    select
        central_index_key,
        company_name,
        standard_industrial_classification,
        state_province_incorporation,
        country_of_incorporation,
        employer_identification_number,
        fiscal_year_end_date,
        filer_status_with_sec,
        date_filed,
        accession_number
    from submissions
    qualify row_number() over (
        partition by central_index_key
        order by date_filed desc, date_accepted desc, accession_number asc
    ) = 1
)

select * from current_attributes
