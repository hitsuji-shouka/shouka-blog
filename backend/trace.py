import logging
from contextlib import contextmanager

from config import settings

logger = logging.getLogger(__name__)

# 无 key → no-op 客户端，trace 旁路不影响主流程
_lf = None
if settings.langfuse_public and settings.langfuse_secret:
    try:
        from langfuse import Langfuse
        _lf = Langfuse(public_key=settings.langfuse_public,
                       secret_key=settings.langfuse_secret, host=settings.langfuse_host)
    except Exception as e:  # noqa: BLE001
        logger.warning("langfuse init failed, tracing off: %s", e)

enabled = _lf is not None


@contextmanager
def trace(name: str, **meta):
    """一次 LLM 调用追踪；无 key 或异常时静默 no-op，记录交回调用方 update()。"""
    if _lf is None:
        yield lambda **_: None
        return
    span = _lf.start_span(name=name, metadata=meta)
    try:
        yield lambda **kw: span.update(**kw)
    except Exception:
        span.update(level="ERROR")
        raise
    finally:
        span.end()
        _lf.flush()
