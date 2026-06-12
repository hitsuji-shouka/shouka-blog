import numpy as np

import posts
import rag


def test_chunk_aggregates_to_size():
    text = "\n\n".join(["a" * 200, "b" * 200, "c" * 200])
    blocks = rag.chunk(text, size=500)
    assert len(blocks) == 2 and all(len(b) <= 500 for b in blocks)


def test_cosine_topk_orders_desc():
    mat = np.array([[1, 0], [0, 1], [1, 1]], dtype=float)
    out = rag.cosine_topk(np.array([1.0, 0.0]), mat, 2)
    assert out[0][0] == 0 and out[0][1] > out[1][1]


def test_search_threshold(tmp_path):
    (tmp_path / "a.md").write_text("---\ntitle: A\ndate: 2026-06-12\ncategory: 学习\n---\nhello\n")
    posts.load(tmp_path)
    rag.build(lambda texts: [[1.0, 0.0] for _ in texts])
    assert [c["slug"] for c in rag.search([1.0, 0.0])] == ["a"]   # sim 1.0 过阈
    assert rag.search([0.0, 1.0]) == []                          # sim 0 低于阈值


def test_build_empty_no_crash(tmp_path):
    posts.load(tmp_path)
    rag.build(lambda t: [[1.0]])
    assert rag.search([1.0]) == []
