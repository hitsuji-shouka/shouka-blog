from __future__ import annotations

import base64
import json
import urllib.request
from pathlib import Path
from typing import Callable
from urllib.parse import urlencode


Transport = Callable[[str, dict[str, str], dict], dict]


def synthesize_to_file(text: str, output_path: Path, settings, transport: Transport | None = None) -> Path:
    if not settings.minimax_api_key:
        raise ValueError("BLOG_MINIMAX_API_KEY is required for MiniMax TTS")
    transport = transport or _post_json
    payload = {
        "model": settings.minimax_tts_model,
        "text": text,
        "stream": False,
        "voice_setting": {
            "voice_id": settings.minimax_tts_voice,
            "speed": 1,
            "vol": 1,
            "pitch": 0,
        },
        "audio_setting": {
            "sample_rate": 32000,
            "bitrate": 128000,
            "format": "mp3",
            "channel": 1,
        },
    }
    headers = {
        "Authorization": f"Bearer {settings.minimax_api_key}",
        "Content-Type": "application/json",
    }
    response = transport(_tts_url(settings), headers, payload)
    audio = _decode_audio(response)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(audio)
    return output_path


def _tts_url(settings) -> str:
    if not settings.minimax_group_id:
        return settings.minimax_tts_base
    sep = "&" if "?" in settings.minimax_tts_base else "?"
    return f"{settings.minimax_tts_base}{sep}{urlencode({'GroupId': settings.minimax_group_id})}"


def _decode_audio(response: dict) -> bytes:
    encoded = response.get("data", {}).get("audio") or response.get("audio")
    if not encoded:
        raise ValueError("MiniMax TTS response did not include audio data")
    try:
        return bytes.fromhex(encoded)
    except ValueError:
        return base64.b64decode(encoded)


def _post_json(url: str, headers: dict[str, str], payload: dict) -> dict:
    req = urllib.request.Request(
        url,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=120) as resp:  # noqa: S310 - configured MiniMax endpoint
        return json.loads(resp.read().decode("utf-8"))
