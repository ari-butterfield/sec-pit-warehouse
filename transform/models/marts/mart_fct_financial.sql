with authoritative_facts as (
    select * from {{ ref('int_facts__authoritative') }}
)

select * from authoritative_facts
