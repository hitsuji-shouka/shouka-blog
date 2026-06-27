from datetime import datetime, timezone, timedelta

from news import NewsItem, NewsSource, dedupe_items, filter_recent, load_openclaw_items, parse_feed


def test_load_openclaw_items_accepts_items_object(tmp_path):
    p = tmp_path / "openclaw.json"
    p.write_text(
        '{"items":[{"source":"CNBC","title":"Fed","url":"https://x/a",'
        '"text":"Rates","published_at":"2026-06-27T06:00:00+08:00"}]}',
        encoding="utf-8",
    )

    item = load_openclaw_items(p)[0]

    assert item.source == "CNBC"
    assert item.title == "Fed"
    assert item.url == "https://x/a"


def test_parse_rss_items_reads_title_url_and_date():
    xml = (
        "<?xml version='1.0'?><rss><channel><item><title>A</title>"
        "<link>https://x/a</link><description>Body</description>"
        "<pubDate>Sat, 27 Jun 2026 00:00:00 GMT</pubDate></item></channel></rss>"
    )

    items = parse_feed(
        xml,
        NewsSource(name="Feed", url="https://feed", kind="rss", market="global", weight=1, language="en"),
    )

    assert items[0].source == "Feed"
    assert items[0].url == "https://x/a"
    assert items[0].published_at == "2026-06-27T00:00:00+00:00"


def test_parse_atom_items_reads_link_href():
    xml = (
        "<?xml version='1.0'?><feed xmlns='http://www.w3.org/2005/Atom'>"
        "<entry><title>A</title><link href='https://x/a'/>"
        "<summary>Body</summary><updated>2026-06-27T00:00:00Z</updated></entry></feed>"
    )

    items = parse_feed(
        xml,
        NewsSource(name="Atom", url="https://feed", kind="rss", market="global", weight=1, language="en"),
    )

    assert items[0].source == "Atom"
    assert items[0].url == "https://x/a"


def test_filter_recent_and_dedupe_keeps_one_copy():
    now = datetime(2026, 6, 27, 8, tzinfo=timezone.utc)
    old = now - timedelta(hours=30)
    items = [
        NewsItem("A", "T", "https://x/a", "Body", now.isoformat(), "global", 1, "en"),
        NewsItem("B", "T", "https://x/a", "Body", now.isoformat(), "global", 1, "en"),
        NewsItem("C", "Old", "https://x/old", "Body", old.isoformat(), "global", 1, "en"),
    ]

    result = dedupe_items(filter_recent(items, now=now, hours=24))

    assert len(result) == 1
    assert result[0].source == "A"
