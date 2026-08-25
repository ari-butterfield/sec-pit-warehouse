with source as (
    select * from {{ source('sec_raw', 'tag') }}
),

renamed as (
    select distinct
        tag,
        version,
        custom as is_custom,
        abstract as is_abstract,
        datatype,
        iord as pit_or_duration,
        crdr as debit_or_credit,
        tlabel as taxonomy_label,
        doc as tag_definition,
        concat(tag, '_', version) as tag_version_key
    from source
)

select * from renamed
