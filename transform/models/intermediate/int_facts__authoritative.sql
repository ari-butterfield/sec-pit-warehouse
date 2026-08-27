with versioned_facts as (
    select * from {{ ref('int_facts__versioned') }}
),

resolved as (
    select
        accession_number,
        central_index_key,
        company_name,
        date_filed,
        date_accepted,
        end_date,
        tag,
        count_of_quarters,
        numeric_value,
        unit_of_measure,
        version,
        co_registrant
    from versioned_facts
    qualify row_number() over (
        partition by central_index_key, count_of_quarters, end_date, tag, unit_of_measure
        order by date_filed desc, date_accepted desc, accession_number asc
    ) = 1
)

select * from resolved
