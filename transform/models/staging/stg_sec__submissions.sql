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
        try_cast(changed as date) as date_name_changed,
        afs as filer_status_with_sec,
        try_cast(wksi as boolean) as well_known_seasoned_issuer,
        fye as fiscal_year_end_date,
        form as submission_type,
        try_cast(period as date) as balance_sheet_date,
        fy as fiscal_year_focus,
        fp as fiscal_period_focus,
        try_strptime(filed, '%Y%m%d')::date as date_filed,
        try_cast(accepted as timestamp) as date_accepted,
        try_cast(prevrpt as boolean) as is_previous_report,
        try_cast(detail as boolean) as is_footnotes,
        instance as instance_doc_name,
        nciks as number_central_index_keys,
        aciks as additional_ciks,
        source_quarter,
        try_cast(source_quarter_start as date) as source_quarter_start
    from source
)

select * from renamed
