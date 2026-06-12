import logging
from typing import Callable

import numpy as np

import posts
from config import settings

logger = logging.getLogger(__name__)

# 内存索引：每块 {slug,title,text,vector}
_chunks: list[dict] = []


def chunk(text: str, size: int = 500) -> list[str]:
    """按段落聚合到约 size 字，避免切断句子。"""
    blocks, buf = [], ""
    for para in (p.strip() for p in text.split("\n\n")):
        if not para:
            continue
        if buf and len(buf) + len(para) > size:
            blocks.append(buf)
            buf = para
        else:
            buf = f"{buf}\n\n{para}" if buf else para
    if buf:
        blocks.append(buf)
    return blocks


def cosine_topk(q: np.ndarray, mat: np.ndarray, k: int) -> list[tuple[int, float]]:
    """返回 (索引, 相似度) top-k，降序。"""
    if mat.size == 0:
        return []
    sims = mat @ q / (np.linalg.norm(mat, axis=1) * np.linalg.norm(q) + 1e-9)
    idx = np.argsort(sims)[::-1][:k]
    return [(int(i), float(sims[i])) for i in idx]


def build(embed: Callable[[list[str]], list[list[float]]]) -> None:
    """对所有文章分块取 embedding 驻内存；失败跳过记日志。"""
    _chunks.clear()
    rows = []
    for meta in posts.list_meta():
        d = posts.get(meta.slug)
        for c in chunk(d.content):
            rows.append({"slug": d.slug, "title": d.title, "text": c})
    if not rows:
        logger.info("rag: no content, all answers fall back to plain LLM")
        return
    try:
        vecs = embed([r["text"] for r in rows])
    except Exception as e:  # noqa: BLE001
        logger.warning("rag: embedding failed, index empty: %s", e)
        return
    for r, v in zip(rows, vecs):
        r["vector"] = np.asarray(v, dtype=np.float32)
    _chunks.extend(rows)
    logger.info("rag: indexed %d chunks", len(_chunks))


def search(qvec: list[float]) -> list[dict]:
    """检索过阈命中块；无命中返空 -> 调用方退回直答。"""
    if not _chunks:
        return []
    mat = np.stack([c["vector"] for c in _chunks])
    hits = cosine_topk(np.asarray(qvec, dtype=np.float32), mat, settings.top_k)
    return [_chunks[i] for i, s in hits if s >= settings.sim_threshold]
