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
- **SCD2 company history** - `dim_company` is Type 1, current attributes only. Company
  renames and SIC reclassifications are lost. SCD2 retains the history.
- **`ddate` sanity test** - across 29 quarters `end_date` runs from `1011-12-31` to
  `2923-12-31`. The lower end is unambiguously filer typos in `ddate`. The upper end is
  mixed: lease and debt maturity schedules report years ahead, but nothing legitimately
  ends in 2923. No test bounds either end yet.
