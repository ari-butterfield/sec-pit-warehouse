with authoritative_facts as (
    select * from {{ ref('int_facts__authoritative') }}
)

select
    central_index_key,
    tag,
    end_date,
    count_of_quarters,
    unit_of_measure,
    count(*) as row_count
from authoritative_facts
group by central_index_key, tag, end_date, count_of_quarters, unit_of_measure
-- confirms the authoritative facts table reports only a single value per fact
having count(*) > 1
