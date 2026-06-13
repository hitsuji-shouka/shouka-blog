import trace


def test_noop_when_no_key():
    assert trace.enabled is False  # 测试环境无 key


def test_trace_context_runs_without_key():
    with trace.trace("t", x=1) as rec:
        rec(output="ok")  # no-op 不报错
