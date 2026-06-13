import posts
import rag
from chat import ChatReq, Msg, build_messages, stream


def fake_embed(texts):
    return [[1.0, 0.0] for _ in texts]


def fake_chat(messages):
    yield "你好"
    yield "，shoka"


def setup_index(tmp_path):
    (tmp_path / "a.md").write_text("---\ntitle: 科技笔记\ndate: 2026-06-12\ncategory: 科技\n---\nrust 很好\n")
    posts.load(tmp_path)
    rag.build(fake_embed)


def collect(req):
    return "".join(stream(req, fake_embed, fake_chat))


def test_hit_emits_sources_then_delta(tmp_path):
    setup_index(tmp_path)
    out = collect(ChatReq(messages=[Msg(role="user", content="rust?")]))
    assert "科技笔记" in out and "你好" in out and "event: done" in out


def test_no_content_falls_back_no_sources(tmp_path):
    posts.load(tmp_path)
    rag.build(fake_embed)
    out = collect(ChatReq(messages=[Msg(role="user", content="hi")]))
    assert '"sources": []' in out and "你好" in out


def test_build_messages_injects_context():
    msgs = build_messages([Msg(role="user", content="q")], [{"title": "T", "text": "ctx"}])
    assert "ctx" in msgs[0]["content"] and msgs[1]["content"] == "q"


def test_error_emits_error_event(tmp_path):
    setup_index(tmp_path)
    def boom(_): raise RuntimeError("down")
    out = "".join(stream(ChatReq(messages=[Msg(role="user", content="q")]), fake_embed, boom))
    assert "助理暂时不可用" in out and "event: done" in out
