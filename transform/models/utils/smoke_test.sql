-- Temporary scaffold model. Proves the dbt -> DuckDB connection and the CI path.
select
    1 as id,
    'sec-pit-warehouse' as project_name,
    current_date as built_at
