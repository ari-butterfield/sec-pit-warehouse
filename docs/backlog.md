# Backlog

Deliberately out of scope for v1.

- **Airflow DAG** - triggering the same dbt project with a different orchestrator.
- **Snowflake portability proof** - point the same models at a Snowflake trial to
  demonstrate adapter portability.
- **Q4 derivation** - Q4 is not filed as a period; derive as FY minus Q1+Q2+Q3.
- **`mart_company_quarter`** - wide per-company-per-quarter reporting mart.
- **Parallel processing** - The _throttle module global only works for single processes.
- **Segments grain decision** - Segments is filtered to segments=''
- **_dbt_load_id** - lineage-tracking column skipped, not wired up in the pandas/parquet ingest path, v2 if needed
