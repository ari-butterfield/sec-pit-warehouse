"""Re-running a loaded quarter must load zero rows. This is the guarantee the
whole backfill design rests on, so it gets a test rather than a memory."""

from pathlib import Path

import dlt
import pytest
from sources import sec_fsds as module

FIXTURE = Path(__file__).parent / "fixtures" / "sample_quarter.zip"


@pytest.fixture
def offline_source(monkeypatch):
    """Serve the committed fixture instead of downloading from SEC."""
    monkeypatch.setattr(module, "download_quarter", lambda *a, **kw: FIXTURE)
    return module.sec_fsds


def _source(offline_source):
    """Config is deliberately fake — download_quarter is patched, nothing hits sec.gov."""
    return offline_source(
        quarters=["2026q1"],
        user_agent="pytest",
        base_url="https://example.invalid/",
        requests_per_second=100,
    )


def _num_rows(pipeline) -> int:
    with pipeline.sql_client() as client:
        with client.execute_query("select count(*) from num") as cursor:
            return cursor.fetchone()[0]


def test_second_run_of_the_same_quarter_loads_nothing(offline_source, tmp_path):
    pipeline = dlt.pipeline(
        pipeline_name="sec_fsds_test",
        destination=dlt.destinations.duckdb(str(tmp_path / "t.duckdb")),
        dataset_name="raw",
        pipelines_dir=str(tmp_path / "state"),
    )

    pipeline.run(_source(offline_source))
    after_first = _num_rows(pipeline)

    pipeline.run(_source(offline_source))
    after_second = _num_rows(pipeline)

    assert after_first > 0
    assert after_second == after_first
