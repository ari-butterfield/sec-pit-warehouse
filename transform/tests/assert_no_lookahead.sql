with versioned_facts as (
    select * from {{ ref('int_facts__versioned') }}
),

authoritative_facts as (
    select * from {{ ref('int_facts__authoritative') }}
)

select v.*
from versioned_facts as v
inner join authoritative_facts as a
    on
        v.central_index_key = a.central_index_key
        and v.tag = a.tag
        and v.end_date = a.end_date
        and v.count_of_quarters = a.count_of_quarters
        and v.unit_of_measure = a.unit_of_measure
-- authoritative facts should contain the most current value.
-- if any facts are more recent than the authoritative fact, this raises an error.
where v.date_filed > a.date_filed
