import logging
import tomllib
from pathlib import Path

from fetch import fetch_handle
from report import write
from summarize import summarize

logging.basicConfig(level=logging.INFO)


def main() -> None:
    handles = tomllib.loads((Path(__file__).parent / "bloggers.toml").read_text())["handles"]
    tweets = [t for h in handles for t in fetch_handle(h)]
    md = summarize(tweets)
    p = write(md)
    print("wrote", p) if p else print("no data, skipped")


if __name__ == "__main__":
    main()
