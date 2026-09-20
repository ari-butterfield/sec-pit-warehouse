with versioned_facts as (
    select * from {{ ref('int_facts__versioned') }}
)

select *
from versioned_facts
-- a fact can't be filed before the period its reporting on. It also can't be filed after today
where date_filed > current_date
