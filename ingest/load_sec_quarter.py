from __future__ import annotations

import argparse

import dlt
from sources.sec_fsds import sec_fsds


def main() -> None:
    """Load one or more SEC quarterly datasets into the local DuckDB warehouse."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("quarters", nargs="+", help="quarters to load, e.g. 2026q1")
    args = parser.parse_args()

    pipeline = dlt.pipeline(
        pipeline_name="sec_fsds",
        destination=dlt.destinations.duckdb("sec_pit.duckdb"),
        dataset_name="raw",
        progress="log",
    )
    print(pipeline.destination.config_params, pipeline.dataset_name)
    load_info = pipeline.run(sec_fsds(quarters=args.quarters), loader_file_format="parquet")
    print(load_info)


if __name__ == "__main__":
    main()
