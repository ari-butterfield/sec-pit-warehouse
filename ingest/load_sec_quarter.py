from __future__ import annotations

import argparse

import dlt
from dlt.destinations.adapters import bigquery_adapter
from sources.sec_fsds import sec_fsds


def main() -> None:
    """Load one or more SEC quarterly datasets into the local DuckDB warehouse."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("quarters", nargs="+", help="quarters to load, e.g. 2026q1")
    parser.add_argument("--destination", choices=["duckdb", "bigquery"], default="duckdb")
    parser.add_argument("--db-path", default="sec_pit.duckdb", help="duckdb destination only")
    args = parser.parse_args()

    source = sec_fsds(quarters=args.quarters)
    bigquery_adapter(
        source.resources["num"], partition="source_quarter_start", cluster=["adsh", "tag"]
    )
    bigquery_adapter(source.resources["sub"], partition="source_quarter_start", cluster=["cik"])

    if args.destination == "bigquery":
        pipeline = dlt.pipeline(
            pipeline_name="sec_fsds_bq",  # separate state from DuckDB pipeline
            destination="bigquery",
            staging="filesystem",  # Parquet lands in GCS, BigQuery loads from there
            dataset_name="sec_raw",
            progress="log",
        )
    else:
        pipeline = dlt.pipeline(
            pipeline_name="sec_fsds",
            destination=dlt.destinations.duckdb(args.db_path),
            dataset_name="raw",
            progress="log",
        )

    print(pipeline.destination.config_params, pipeline.dataset_name)
    load_info = pipeline.run(source, loader_file_format="parquet")
    print(load_info)


if __name__ == "__main__":
    main()
