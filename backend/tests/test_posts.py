import pytest

import posts

GOOD_A = """---
title: A
date: 2026-06-10
category: 科技
tags: [x, y]
summary: sa
---
body a
::bilibili{id=BV1}
"""

GOOD_B = """---
title: B
date: 2026-06-12
category: 随笔
summary: sb
cover: http://c
---
body b
"""

BAD_CATEGORY = """---
title: Bad
date: 2026-06-11
category: 时政
---
nope
"""

BAD_FRONTMATTER = "no frontmatter at all"


@pytest.fixture
def content(tmp_path):
    (tmp_path / "a.md").write_text(GOOD_A)
    (tmp_path / "b.md").write_text(GOOD_B)
    (tmp_path / "bad.md").write_text(BAD_CATEGORY)
    (tmp_path / "broken.md").write_text(BAD_FRONTMATTER)
    posts.load(tmp_path)
    return tmp_path


def test_loads_valid_skips_invalid(content):
    metas = posts.list_meta()
    assert [m.slug for m in metas] == ["b", "a"]  # date desc, bad ones skipped


def test_detail_has_content(content):
    d = posts.get("a")
    assert "body a" in d.content and d.tags == ["x", "y"]


def test_missing_slug_returns_none(content):
    assert posts.get("nope") is None


def test_category_filter(content):
    assert [m.slug for m in posts.list_meta("随笔")] == ["b"]
    assert posts.list_meta("科技")[0].slug == "a"


def test_invalid_category_empty(content):
    assert posts.list_meta("时政") == []


def test_categories_counts(content):
    counts = {c["category"]: c["count"] for c in posts.categories()}
    assert counts == {"科技": 1, "理财": 0, "随笔": 1}
