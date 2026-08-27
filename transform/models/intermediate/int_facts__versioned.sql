{{ config(materialized='table') }}

with submissions as (
    select * from {{ ref('stg_sec__submissions') }}
),

numeric_facts as (
    select * from {{ ref('stg_sec__numeric_facts') }}
),

joined as (
    select
        s.accession_number,
        s.central_index_key,
        s.company_name,
        s.date_filed,
        s.date_accepted,
        n.end_date,
        n.tag,
        n.count_of_quarters,
        n.numeric_value,
        n.unit_of_measure,
        n.version,
        n.co_registrant
    from
        submissions as s
    inner join numeric_facts as n
        on s.accession_number = n.accession_number
)

select * from joined
