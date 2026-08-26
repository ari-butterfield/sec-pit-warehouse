{{ config(materialized='view') }}

with source as (
    select * from {{ source('sec_raw', 'num') }}
),

renamed as (
    select
        adsh as accession_number,
        tag,
        version,
        try_strptime(ddate, '%Y%m%d')::date as end_date,
        qtrs as count_of_quarters,
        uom as unit_of_measure,
        segments,
        coreg as co_registrant,
        try_cast(value as double) as numeric_value,
        footnote,
        source_quarter,
        try_cast(source_quarter_start as date) as source_quarter_start
    from source
)

select * from renamed
where segments = ''
