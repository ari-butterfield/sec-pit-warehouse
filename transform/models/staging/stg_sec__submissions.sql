with source as (
    select * from {{ source('sec_raw', 'sub') }}
),

renamed as (
    select
        adsh as accession_number,
        cik as central_index_key,
        name as company_name,
        sic as standard_industrial_classification,
        countryinc as country_of_incorporation,
        stprinc as state_province_incorporation,
        ein as employer_identification_number,
        former as former_name,
        {{ safe_cast_cross_db('changed', 'date') }} as date_name_changed,
        afs as filer_status_with_sec,
        {{ safe_cast_cross_db('wksi', 'boolean') }} as well_known_seasoned_issuer,
        fye as fiscal_year_end_date,
        form as submission_type,
        {{ safe_cast_cross_db('period', 'date') }} as balance_sheet_date,
        fy as fiscal_year_focus,
        fp as fiscal_period_focus,
        {{ parse_date_cross_db('filed', '%Y%m%d') }} as date_filed,
        {{ safe_cast_cross_db('accepted', 'timestamp') }} as date_accepted,
        {{ safe_cast_cross_db('prevrpt', 'boolean') }} as is_previous_report,
        {{ safe_cast_cross_db('detail', 'boolean') }} as is_footnotes,
        instance as instance_doc_name,
        nciks as number_central_index_keys,
        aciks as additional_ciks,
        source_quarter,
        {{ safe_cast_cross_db('source_quarter_start', 'date') }} as source_quarter_start
    from source
)

select * from renamed
