from __future__ import annotations

import json
import tomllib
import urllib.request
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime
from pathlib import Path
from typing import Callable, Iterable


@dataclass(frozen=True)
class NewsSource:
    name: str
    url: str
    kind: str
    market: str
    weight: int = 1
    language: str = "zh"


@dataclass(frozen=True)
class NewsItem:
    source: str
    title: str
    url: str
    text: str
    published_at: str
    market: str = ""
    weight: int = 1
    language: str = "zh"


def load_openclaw_items(path: Path) -> list[NewsItem]:
    raw = json.loads(path.read_text(encoding="utf-8"))
    rows = raw.get("items", raw) if isinstance(raw, dict) else raw
    items: list[NewsItem] = []
    for row in rows:
        items.append(
            NewsItem(
                source=str(row.get("source") or row.get("site") or "OpenClaw"),
                title=str(row.get("title") or "").strip(),
                url=str(row.get("url") or "").strip(),
                text=str(row.get("text") or row.get("summary") or row.get("content") or "").strip(),
                published_at=str(row.get("published_at") or row.get("date") or ""),
                market=str(row.get("market") or ""),
                weight=int(row.get("weight") or 1),
                language=str(row.get("language") or "zh"),
            )
        )
    return [i for i in items if i.title and i.url]


def load_sources(path: Path, topic: str = "finance") -> list[NewsSource]:
    data = tomllib.loads(path.read_text(encoding="utf-8"))
    rows = data.get(topic, {}).get("sources", [])
    return [
        NewsSource(
            name=str(row["name"]),
            url=str(row["url"]),
            kind=str(row.get("kind") or "rss"),
            market=str(row.get("market") or ""),
            weight=int(row.get("weight") or 1),
            language=str(row.get("language") or "zh"),
        )
        for row in rows
    ]


def fetch_sources(
    sources: Iterable[NewsSource],
    opener: Callable[[str], bytes] | None = None,
) -> list[NewsItem]:
    opener = opener or _open_url
    items: list[NewsItem] = []
    for source in sources:
        try:
            body = opener(source.url).decode("utf-8", errors="replace")
            items.extend(parse_feed(body, source))
        except Exception:
            continue
    return items


def parse_feed(xml: str, source: NewsSource) -> list[NewsItem]:
    root = ET.fromstring(xml)
    if _strip_ns(root.tag) == "feed":
        return _parse_atom(root, source)
    return _parse_rss(root, source)


def filter_recent(
    items: Iterable[NewsItem],
    now: datetime | None = None,
    hours: int = 24,
) -> list[NewsItem]:
    now = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    cutoff = now - timedelta(hours=hours)
    recent: list[NewsItem] = []
    for item in items:
        published = _parse_datetime(item.published_at)
        if published is None or published >= cutoff:
            recent.append(item)
    return recent


def dedupe_items(items: Iterable[NewsItem]) -> list[NewsItem]:
    seen: set[str] = set()
    unique: list[NewsItem] = []
    for item in items:
        key = item.url.lower().strip() or item.title.lower().strip()
        if not key or key in seen:
            continue
        seen.add(key)
        unique.append(item)
    return unique


def _parse_rss(root: ET.Element, source: NewsSource) -> list[NewsItem]:
    items: list[NewsItem] = []
    for node in root.findall(".//item"):
        title = _text(node, "title")
        url = _text(node, "link")
        text = _text(node, "description")
        published = _normalize_datetime(_text(node, "pubDate") or _text(node, "date"))
        if title and url:
            items.append(_item(source, title, url, text, published))
    return items


def _parse_atom(root: ET.Element, source: NewsSource) -> list[NewsItem]:
    items: list[NewsItem] = []
    for node in root.findall(".//{*}entry"):
        title = _text(node, "title")
        url = ""
        link = node.find("{*}link")
        if link is not None:
            url = link.attrib.get("href", "")
        text = _text(node, "summary") or _text(node, "content")
        published = _normalize_datetime(_text(node, "updated") or _text(node, "published"))
        if title and url:
            items.append(_item(source, title, url, text, published))
    return items


def _item(source: NewsSource, title: str, url: str, text: str, published_at: str) -> NewsItem:
    return NewsItem(
        source=source.name,
        title=title.strip(),
        url=url.strip(),
        text=text.strip(),
        published_at=published_at,
        market=source.market,
        weight=source.weight,
        language=source.language,
    )


def _text(node: ET.Element, child_name: str) -> str:
    child = node.find(child_name)
    if child is None:
        child = node.find(f"{{*}}{child_name}")
    return "".join(child.itertext()).strip() if child is not None else ""


def _strip_ns(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def _normalize_datetime(value: str) -> str:
    parsed = _parse_datetime(value)
    return parsed.isoformat() if parsed else value


def _parse_datetime(value: str) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)
    except ValueError:
        pass
    try:
        parsed = parsedate_to_datetime(value)
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed.astimezone(timezone.utc)
    except (TypeError, ValueError):
        return None


def _open_url(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "shouka-blog-news/1.0"})
    with urllib.request.urlopen(req, timeout=20) as resp:  # noqa: S310 - configured user sources
        return resp.read()
