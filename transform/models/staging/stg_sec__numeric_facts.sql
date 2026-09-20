{{ config(materialized='view') }}

with source as (
    select * from {{ source('sec_raw', 'num') }}
),

renamed as (
    select
        adsh as accession_number,
        tag,
        version,
        {{ parse_date_cross_db('ddate', '%Y%m%d') }} as end_date,
        qtrs as count_of_quarters,
        uom as unit_of_measure,
        segments,
        coreg as co_registrant,
        {{ safe_cast_cross_db('value', 'float64'
            if (target is defined and target.type == 'bigquery') else 'double'
        ) }} as numeric_value,
        footnote,
        source_quarter,
        {{ safe_cast_cross_db('source_quarter_start', 'date') }} as source_quarter_start
    from source
)

select * from renamed
where segments = ''
