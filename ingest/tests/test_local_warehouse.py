from pathlib import Path

import pytest

duckdb = pytest.importorskip("duckdb")

DB = Path(__file__).resolve().parents[1] / "sec_pit.duckdb"
pytestmark = pytest.mark.skipif(
    not DB.exists(), reason="no local DuckDB load; run load_sec_quarter.py"
)


@pytest.fixture(scope="module")
def con():
    connection = duckdb.connect(str(DB), read_only=True)
    yield connection
    connection.close()


@pytest.mark.parametrize("table", ["sub", "num", "tag", "pre"])
def test_table_is_not_empty(con, table):
    assert con.sql(f"select count(*) from raw.{table}").fetchone()[0] > 0


def test_every_numeric_fact_has_a_submission(con):
    orphans = con.sql(
        "select count(*) from raw.num n left join raw.sub s on s.adsh = n.adsh where s.adsh is null"
    ).fetchone()[0]
    assert orphans == 0


def test_apple_has_revenue_facts(con):
    # Replace the tag with whatever Apple actually files (see Task 2.5).
    rows = con.sql(
        "select count(*) from raw.num n join raw.sub s on s.adsh = n.adsh "
        "where s.cik = '320193' and n.tag like '%Revenue%'"
    ).fetchone()[0]
    assert rows > 0
