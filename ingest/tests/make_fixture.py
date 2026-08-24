"""Build a tiny quarterly ZIP from a cached real one, for use in CI tests."""

from __future__ import annotations

import sys
import zipfile
from pathlib import Path

ROWS = 200
MEMBERS = ("sub.txt", "num.txt", "tag.txt", "pre.txt")


def main(source: Path, target: Path) -> None:
    with zipfile.ZipFile(source) as src, zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as dst:
        for member in MEMBERS:
            with src.open(member) as handle:
                head = b"".join(line for _, line in zip(range(ROWS + 1), handle, strict=False))
            dst.writestr(member, head)


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))
