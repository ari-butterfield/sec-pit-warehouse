with versioned_facts as (
    select * from {{ ref('int_facts__versioned') }}
),

partitioned_filings as (
    select
        central_index_key,
        tag,
        end_date,
        count_of_quarters,
        unit_of_measure,
        numeric_value,
        accession_number,
        date_filed,
        date_accepted,
        rank() over (
            partition by central_index_key, tag, count_of_quarters, unit_of_measure, end_date
            order by date_filed asc, date_accepted asc, accession_number asc
        ) as revision_counter
    from versioned_facts
),

revisions as (
    select
        central_index_key,
        tag,
        end_date,
        count_of_quarters,
        unit_of_measure,
        numeric_value as revised_value,
        lag(numeric_value, 1) over (
            partition by central_index_key, tag, count_of_quarters, unit_of_measure, end_date
            order by date_filed asc, date_accepted asc, accession_number asc
        ) as original_value,
        numeric_value - lag(numeric_value, 1) over (
            partition by central_index_key, tag, count_of_quarters, unit_of_measure, end_date
            order by date_filed asc, date_accepted asc, accession_number asc
        ) as delta,
        {{ datediff_cross_db('day', 'lag(date_filed, 1) over (
            partition by central_index_key, tag, count_of_quarters, unit_of_measure, end_date
            order by date_filed asc, date_accepted asc, accession_number asc
        )', 'date_filed') }} as lag_days,
        accession_number as revising_adsh,
        lag(accession_number, 1) over (
            partition by central_index_key, tag, count_of_quarters, unit_of_measure, end_date
            order by date_filed asc, date_accepted asc, accession_number asc
        ) as original_adsh
    from partitioned_filings
    qualify revision_counter >= 2
)

select * from revisions
