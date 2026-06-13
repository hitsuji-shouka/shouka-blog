import logging
import sys
import tomllib
from pathlib import Path

from fetch import fetch_handle
from report import write
from summarize import summarize

logging.basicConfig(level=logging.INFO)


def main(topic: str = "finance") -> None:
    cfg = tomllib.loads((Path(__file__).parent / "bloggers.toml").read_text())[topic]
    items = [t for h in cfg["handles"] for t in fetch_handle(h)]
    md = summarize(items, cfg["category"])
    p = write(md, cfg["category"], cfg["prefix"], cfg["title"])
    print("wrote", p) if p else print("no data, skipped")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "finance")
