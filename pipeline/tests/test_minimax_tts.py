from types import SimpleNamespace

from minimax_tts import synthesize_to_file


def settings():
    return SimpleNamespace(
        minimax_api_key="key",
        minimax_tts_base="https://mini.example/t2a_v2",
        minimax_group_id="group",
        minimax_tts_model="speech-test",
        minimax_tts_voice="voice-test",
    )


def test_synthesize_to_file_writes_hex_audio(tmp_path):
    out = tmp_path / "a.mp3"

    def fake_transport(url, headers, payload):
        assert url == "https://mini.example/t2a_v2?GroupId=group"
        assert headers["Authorization"] == "Bearer key"
        assert payload["model"] == "speech-test"
        assert payload["text"] == "hello"
        assert payload["voice_setting"]["voice_id"] == "voice-test"
        return {"data": {"audio": "68656c6c6f"}}

    path = synthesize_to_file("hello", out, settings(), transport=fake_transport)

    assert path == out
    assert out.read_bytes() == b"hello"


def test_synthesize_to_file_writes_base64_audio(tmp_path):
    out = tmp_path / "a.mp3"

    def fake_transport(_url, _headers, _payload):
        return {"data": {"audio": "aGVsbG8="}}

    synthesize_to_file("hello", out, settings(), transport=fake_transport)

    assert out.read_bytes() == b"hello"


def test_synthesize_requires_api_key(tmp_path):
    cfg = settings()
    cfg.minimax_api_key = ""

    try:
        synthesize_to_file("hello", tmp_path / "a.mp3", cfg, transport=lambda *_: {})
    except ValueError as exc:
        assert "BLOG_MINIMAX_API_KEY" in str(exc)
    else:
        raise AssertionError("expected missing key error")
