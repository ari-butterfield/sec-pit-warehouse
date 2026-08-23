"""dlt source for SEC Financial Statement Data Sets quarterly ZIPs"""

from __future__ import annotations

import csv
import time
import zipfile
from collections.abc import Iterator
from pathlib import Path

import dlt
import pandas as pd
import requests

CACHE_DIR = Path(__file__).resolve().parents[1] / ".cache"
CHUNK_ROWS = 200000

SUB_COLUMNS = [
    "adsh",
    "cik",
    "name",
    "sic",
    "countryinc",
    "stprinc",
    "ein",
    "former",
    "changed",
    "afs",
    "wksi",
    "fye",
    "form",
    "period",
    "fy",
    "fp",
    "filed",
    "accepted",
    "prevrpt",
    "detail",
    "instance",
    "nciks",
    "aciks",
]
NUM_COLUMNS = [
    "adsh",
    "tag",
    "version",
    "coreg",
    "ddate",
    "qtrs",
    "uom",
    "value",
    "footnote",
    "segments",
]
TAG_COLUMNS = ["tag", "version", "custom", "abstract", "datatype", "iord", "crdr", "tlabel", "doc"]
PRE_COLUMNS = ["adsh", "report", "line", "stmt", "inpth", "rfile", "tag", "version", "plabel"]

_last_request_at = 0.0


def _throttle(requests_per_second: float) -> None:
    global _last_request_at
    gap = 1.0 / requests_per_second
    wait = gap - (time.monotonic() - _last_request_at)
    if wait > 0:
        time.sleep(wait)
    _last_request_at = time.monotonic()


def download_quarter(
    quarter: str, user_agent: str, base_url: str, requests_per_second: float
) -> Path:
    """Fetch one quarterly ZIP, caching it on disk. Returns local path."""
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    target = CACHE_DIR / f"{quarter}.zip"
    if target.exists():
        return target

    _throttle(requests_per_second)
    response = requests.get(
        f"{base_url.rstrip('/')}/{quarter}.zip",
        headers={"User-Agent": user_agent},
        stream=True,
        timeout=120,
    )
    response.raise_for_status()

    # Download ZIP with .part suffix and remove suffix after completion
    # This is so an interrupted run doesn't leave a valid-looking file
    staging = target.with_suffix(".part")
    with staging.open("wb") as fh:
        for block in response.iter_content(chunk_size=1024 * 1024):
            fh.write(block)
    staging.rename(target)
    return target


def read_source_file(
    zip_path: Path, source_file: str, columns: list[str]
) -> Iterator[pd.DataFrame]:
    """Yield chunks of one tab-delimited source_file of the quarterly ZIP."""
    with zipfile.ZipFile(zip_path) as archive, archive.open(source_file) as handle:
        chunks = pd.read_csv(
            handle,
            sep="\t",
            dtype=str,
            quoting=csv.QUOTE_NONE,
            encoding="utf-8",
            encoding_errors="replace",
            na_filter=False,
            on_bad_lines="warn",
            chunksize=CHUNK_ROWS,
        )
        for chunk in chunks:
            yield chunk.reindex(columns=columns)


@dlt.source(name="sec")
def sec_fsds(
    quarters: list[str],
    user_agent: str = dlt.config.value,
    base_url: str = dlt.config.value,
    requests_per_second: float = dlt.config.value,
):
    """Build the four SEC dataset resources for requested quarters"""

    def load(source_file: str, columns: list[str]):
        """Yield chunks of one file for each quarter not already loaded."""
        already_loaded = dlt.current.resource_state().setdefault("loaded_quarters", [])
        for quarter in quarters:
            if quarter in already_loaded:
                continue
            zip_path = download_quarter(quarter, user_agent, base_url, requests_per_second)
            for chunk in read_source_file(zip_path, source_file, columns):
                chunk["source_quarter"] = quarter
                yield chunk
            already_loaded.append(quarter)

    @dlt.resource(name="sub", write_disposition="append")
    def sub():
        yield from load("sub.txt", SUB_COLUMNS)

    @dlt.resource(name="num", write_disposition="append")
    def num():
        yield from load("num.txt", NUM_COLUMNS)

    @dlt.resource(name="tag", write_disposition="append")
    def tag():
        yield from load("tag.txt", TAG_COLUMNS)

    @dlt.resource(name="pre", write_disposition="append")
    def pre():
        yield from load("pre.txt", PRE_COLUMNS)

    return [sub(), num(), tag(), pre()]
