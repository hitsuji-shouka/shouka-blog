from datetime import date

from models import Category, PostDetail, PostMeta


def test_post_meta_defaults():
    m = PostMeta(slug="a", title="A", date=date(2026, 6, 12), category="科技")
    assert m.tags == []
    assert m.summary == ""
    assert m.cover is None
    assert m.category is Category.TECH


def test_post_detail_extends_meta_with_content():
    d = PostDetail(
        slug="a", title="A", date=date(2026, 6, 12), category="随笔",
        tags=["x"], summary="s", cover="http://c", content="# hi",
    )
    assert d.content == "# hi"
    assert d.category is Category.ESSAY
    assert isinstance(d, PostMeta)


def test_invalid_category_rejected():
    import pytest
    with pytest.raises(ValueError):
        PostMeta(slug="a", title="A", date=date(2026, 6, 12), category="时政")
