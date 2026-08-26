from pathlib import Path

from sources.sec_fsds import NUM_COLUMNS, SUB_COLUMNS, read_source_file

FIXTURE = Path(__file__).parent / "fixtures" / "sample_quarter.zip"


def test_sub_parses_with_expected_columns():
    chunks = list(read_source_file(FIXTURE, "sub.txt", SUB_COLUMNS))
    frame = chunks[0]
    assert list(frame.columns) == SUB_COLUMNS
    assert len(frame) > 0
    assert frame["adsh"].str.len().eq(20).all()


def test_num_rows_all_carry_an_accession_number():
    frame = next(read_source_file(FIXTURE, "num.txt", NUM_COLUMNS))
    assert frame["adsh"].ne("").all()
    assert frame["qtrs"].isin({"0", "1", "2", "3", "4"}).all()


def test_quoting_does_not_shift_columns():
    """SEC text fields contain unbalanced quotes; QUOTE_NONE keeps rows aligned."""
    frame = next(read_source_file(FIXTURE, "num.txt", NUM_COLUMNS))
    assert frame["ddate"].str.fullmatch(r"\d{8}").all()
