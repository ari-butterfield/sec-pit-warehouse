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
),

-- Most re-filings repeat the number unchanged. Classifying rather than
-- filtering keeps the reassertion lineage, while we can still count
-- reassertions where the value changed.
classified as (
    select
        central_index_key,
        tag,
        end_date,
        count_of_quarters,
        unit_of_measure,
        original_value,
        revised_value,
        delta,
        lag_days,
        original_adsh,
        revising_adsh,
        case
            when original_value is null and revised_value is null then 'both_absent'
            when original_value is null then 'first_reported_value'
            when revised_value is null then 'value_withdrawn'
            when delta = 0 then 'reaffirmation'
            else 'value_revision'
        end as revision_type
    from revisions
)

select * from classified
