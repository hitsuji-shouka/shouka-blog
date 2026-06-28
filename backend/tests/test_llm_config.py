from types import SimpleNamespace

from config import Settings
from pathlib import Path
from llm import resolve_chat_config


def test_minimax_key_takes_chat_precedence():
    cfg = SimpleNamespace(
        minimax_api_key="mx",
        minimax_chat_base="https://mini.example/v1",
        minimax_chat_model="MiniMax-Test",
        deepseek_key="ds",
        deepseek_base="https://deep.example",
        deepseek_model="deep-test",
    )

    assert resolve_chat_config(cfg) == ("mx", "https://mini.example/v1", "MiniMax-Test")


def test_deepseek_is_fallback_when_minimax_missing():
    cfg = SimpleNamespace(
        minimax_api_key="",
        minimax_chat_base="https://mini.example/v1",
        minimax_chat_model="MiniMax-Test",
        deepseek_key="ds",
        deepseek_base="https://deep.example",
        deepseek_model="deep-test",
    )

    assert resolve_chat_config(cfg) == ("ds", "https://deep.example", "deep-test")


def test_bailian_embedding_is_default_provider():
    cfg = Settings()

    assert cfg.embed_base == "https://dashscope.aliyuncs.com/compatible-mode/v1"
    assert cfg.embed_model == "text-embedding-v4"


def test_settings_load_project_root_env_file():
    env_file = Settings.model_config["env_file"]

    assert Path(env_file).is_absolute()
    assert Path(env_file).name == ".env"
    assert Path(env_file).parent == Path(__file__).resolve().parents[2]
