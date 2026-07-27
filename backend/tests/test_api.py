import pytest
from fastapi.testclient import TestClient

import posts
from main import app, build_rag_if_configured


@pytest.fixture(autouse=True)
def loaded(tmp_path):
    (tmp_path / "b.md").write_text(
        "---\ntitle: B\ndate: 2026-06-12\ncategory: 随笔\nsummary: sb\n"
        "audio: /audio/b.mp3\nsources: [CNBC, Reuters]\n---\nbody b\n"
    )
    (tmp_path / "a.md").write_text(
        "---\ntitle: A\ndate: 2026-06-10\ncategory: 科技\n---\nbody a\n"
    )
    posts.load(tmp_path)


client = TestClient(app)


def test_list_desc_no_content():
    r = client.get("/api/posts")
    assert r.status_code == 200
    slugs = [p["slug"] for p in r.json()]
    assert slugs == ["b", "a"]
    assert "content" not in r.json()[0]


def test_detail_has_content():
    r = client.get("/api/posts/a")
    assert r.status_code == 200 and "body a" in r.json()["content"]


def test_audio_metadata_is_returned():
    data = client.get("/api/posts/b").json()
    assert data["audio"] == "/audio/b.mp3"
    assert data["sources"] == ["CNBC", "Reuters"]


def test_audio_file_served_from_public_audio(tmp_path, monkeypatch):
    audio_dir = tmp_path / "audio"
    audio_dir.mkdir()
    (audio_dir / "b.mp3").write_bytes(b"ID3mp3")
    monkeypatch.setattr("main.settings.audio_dir", audio_dir)

    r = client.get("/audio/b.mp3")

    assert r.status_code == 200
    assert r.content == b"ID3mp3"
    assert r.headers["content-type"] == "audio/mpeg"


def test_missing_returns_404():
    assert client.get("/api/posts/nope").status_code == 404


def test_category_filter_and_invalid():
    assert [p["slug"] for p in client.get("/api/posts?category=随笔").json()] == ["b"]
    assert client.get("/api/posts?category=时政").json() == []


def test_api_sees_post_added_after_initial_load(tmp_path):
    (tmp_path / "tech-20260628.md").write_text(
        "---\ntitle: 科技早报 · 06-28\ndate: 2026-06-28\ncategory: 科技\n"
        "tags: [每日报告, 科技早报]\n---\nnew tech body\n"
    )

    r = client.get("/api/posts/tech-20260628")

    assert r.status_code == 200
    assert r.json()["content"] == "new tech body"


def test_categories():
    counts = {c["category"]: c["count"] for c in client.get("/api/categories").json()}
    assert counts == {"科技": 1, "理财": 0, "随笔": 1}


def test_health_check_reports_ready():
    r = client.get("/api/health")

    assert r.status_code == 200
    assert r.json() == {"status": "ok", "service": "shoka-blog"}


def test_version_reports_deployed_revision(monkeypatch):
    monkeypatch.setenv("APP_VERSION", "test-sha")

    r = client.get("/api/version")

    assert r.status_code == 200
    assert r.json() == {"version": "test-sha", "service": "shoka-blog"}


def test_robots_txt_points_to_sitemap(monkeypatch):
    monkeypatch.setenv("SITE_DOMAIN", "blog.example.test")

    r = client.get("/robots.txt")

    assert r.status_code == 200
    assert r.headers["content-type"].startswith("text/plain")
    assert "User-agent: *" in r.text
    assert "Allow: /" in r.text
    assert "Sitemap: https://blog.example.test/sitemap.xml" in r.text


def test_sitemap_lists_public_pages(monkeypatch):
    monkeypatch.setenv("SITE_DOMAIN", "blog.example.test")

    r = client.get("/sitemap.xml")

    assert r.status_code == 200
    assert r.headers["content-type"].startswith("application/xml")
    assert "<loc>https://blog.example.test/</loc>" in r.text
    assert "<loc>https://blog.example.test/category/%E7%A7%91%E6%8A%80</loc>" in r.text
    assert "<loc>https://blog.example.test/category/%E9%9A%8F%E7%AC%94</loc>" in r.text
    assert "<loc>https://blog.example.test/post/b</loc>" in r.text
    assert "<loc>https://blog.example.test/post/a</loc>" in r.text
    assert "<lastmod>2026-06-12</lastmod>" in r.text


def test_feed_xml_lists_recent_posts(monkeypatch):
    monkeypatch.setenv("SITE_DOMAIN", "blog.example.test")

    r = client.get("/feed.xml")

    assert r.status_code == 200
    assert r.headers["content-type"].startswith("application/rss+xml")
    assert '<rss version="2.0">' in r.text
    assert "<title>Shouka Blog</title>" in r.text
    assert "<link>https://blog.example.test/</link>" in r.text
    assert "<title>B</title>" in r.text
    assert "<link>https://blog.example.test/post/b</link>" in r.text
    assert "<title>A</title>" in r.text
    assert "<link>https://blog.example.test/post/a</link>" in r.text


def test_static_home_uses_absolute_public_share_urls(monkeypatch):
    monkeypatch.setenv("SITE_DOMAIN", "blog.example.test")

    r = client.get("/")

    assert r.status_code == 200
    assert 'rel="canonical" href="https://blog.example.test/"' in r.text
    assert 'property="og:url" content="https://blog.example.test/"' in r.text
    assert 'property="og:image" content="https://blog.example.test/bg/hero-space.jpg"' in r.text
    assert 'name="twitter:image" content="https://blog.example.test/bg/hero-space.jpg"' in r.text


def test_build_rag_skips_without_embed_key():
    calls = []

    assert build_rag_if_configured("", lambda embed: calls.append(embed), object()) is False
    assert calls == []


def test_build_rag_runs_with_embed_key():
    calls = []
    embed = object()

    assert build_rag_if_configured("key", lambda fn: calls.append(fn), embed) is True
    assert calls == [embed]
