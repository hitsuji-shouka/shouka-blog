from __future__ import annotations

import argparse
import logging
import sys
import tomllib
from dataclasses import asdict
from datetime import date
from pathlib import Path

try:
    from . import report
    from .fetch import fetch_handle
    from .minimax_tts import synthesize_to_file
    from .news import dedupe_items, fetch_sources, filter_recent, load_openclaw_items, load_sources
    from .publish import publish
    from .summarize import summarize, summarize_news
except ImportError:
    import report
    from fetch import fetch_handle
    from minimax_tts import synthesize_to_file
    from news import dedupe_items, fetch_sources, filter_recent, load_openclaw_items, load_sources
    from publish import publish
    from summarize import summarize, summarize_news

from config import settings  # noqa: E402

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

ROOT = Path(__file__).resolve().parent.parent
AUDIO_DIR = ROOT / "frontend" / "public" / "audio"
SOURCES = Path(__file__).parent / "sources.toml"


def today() -> date:
    return date.today()


def main(argv: list[str] | str | None = None) -> Path | None:
    if isinstance(argv, str):
        return run_legacy(argv)
    args = parse_args(argv)
    if args.mode == "legacy":
        return run_legacy(args.topic)
    return run_news(args)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate daily blog reports")
    parser.add_argument("topic", nargs="?", default="finance")
    parser.add_argument("--mode", choices=["legacy", "news"], default="legacy")
    parser.add_argument("--input", type=Path, help="OpenClaw JSON input path")
    parser.add_argument("--with-audio", action="store_true")
    parser.add_argument("--publish", action="store_true")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--min-items", type=int, default=5)
    parser.add_argument("--hours", type=int, default=24)
    return parser.parse_args(argv)


def run_legacy(topic: str = "finance") -> Path | None:
    cfg = tomllib.loads((Path(__file__).parent / "bloggers.toml").read_text(encoding="utf-8"))[topic]
    items = [t for h in cfg["handles"] for t in fetch_handle(h)]
    md = summarize(items, cfg["category"])
    p = report.write(md, cfg["category"], cfg["prefix"], cfg["title"])
    print("wrote", p) if p else print("no data, skipped")
    return p


def run_news(args: argparse.Namespace) -> Path | None:
    cfg = tomllib.loads((Path(__file__).parent / "bloggers.toml").read_text(encoding="utf-8"))[args.topic]
    d = today()
    target = report.CONTENT / f"{cfg['prefix']}-{d:%Y%m%d}.md"
    if target.exists() and not args.force:
        logger.info("%s exists, skipped. Use --force to overwrite.", target.name)
        return None

    items = _load_news_items(args)
    if len(items) < args.min_items:
        logger.warning("only %d news items, need %d; skipped", len(items), args.min_items)
        return None

    brief = summarize_news([asdict(item) for item in items], cfg["category"])
    article = brief["article"]
    script = brief["script"]
    if not article.strip():
        logger.warning("empty article summary, skipped")
        return None

    audio_url = None
    audio_path = None
    if args.with_audio:
        audio_path = AUDIO_DIR / f"{cfg['prefix']}-{d:%Y%m%d}.mp3"
        audio_path.parent.mkdir(parents=True, exist_ok=True)
        synthesize_to_file(script or article, audio_path, settings)
        audio_url = f"/audio/{audio_path.name}"

    sources = sorted({item.source for item in items if item.source})
    path = report.write(
        article,
        cfg["category"],
        cfg["prefix"],
        "理财早报" if args.topic == "finance" else cfg["title"],
        d,
        tags=["每日报告", "理财早报"] if args.topic == "finance" else ["每日报告"],
        audio=audio_url,
        sources=sources,
    )
    if path and args.publish:
        publish_paths = [path]
        if audio_path:
            publish_paths.append(audio_path)
        publish(publish_paths, f"chore: publish {cfg['prefix']} briefing {d:%Y-%m-%d}", push=True)
    print("wrote", path) if path else print("no data, skipped")
    return path


def _load_news_items(args: argparse.Namespace):
    if args.input:
        raw = load_openclaw_items(args.input)
    else:
        raw = fetch_sources(load_sources(SOURCES, args.topic))
    return dedupe_items(filter_recent(raw, hours=args.hours))


if __name__ == "__main__":
    main(sys.argv[1:])
