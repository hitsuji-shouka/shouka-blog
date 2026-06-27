import pytest
from fastapi.testclient import TestClient

import posts
from main import app


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


def test_missing_returns_404():
    assert client.get("/api/posts/nope").status_code == 404


def test_category_filter_and_invalid():
    assert [p["slug"] for p in client.get("/api/posts?category=随笔").json()] == ["b"]
    assert client.get("/api/posts?category=时政").json() == []


def test_categories():
    counts = {c["category"]: c["count"] for c in client.get("/api/categories").json()}
    assert counts == {"科技": 1, "理财": 0, "随笔": 1}
