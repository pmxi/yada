#!/usr/bin/env python3
"""Shared helpers and types for speech pipeline modules."""

from __future__ import annotations

import mimetypes
from dataclasses import dataclass
from pathlib import Path

REWRITE_PROMPT = """Rewrite the raw text with correct grammar, punctuation and capitalization.
Preserve meaning. Return plain text only."""


@dataclass
class PipelineResult:
    pipeline: str
    flac_path: str
    asr_model: str
    rewrite_model: str
    raw_transcript: str
    rewritten_text: str
    transcribe_seconds: float
    rewrite_seconds: float
    total_seconds: float


def validate_flac_path(flac_path: str | Path) -> Path:
    path = Path(flac_path).expanduser().resolve()
    if not path.exists() or not path.is_file():
        raise FileNotFoundError(f"FLAC file not found: {path}")
    if path.suffix.lower() != ".flac":
        raise ValueError(f"Expected .flac input, got: {path.name}")
    return path


def requests_post(*args, **kwargs):
    try:
        import requests
    except Exception as exc:  # noqa: BLE001
        raise RuntimeError(
            "HTTP calls require `requests`. Install with: "
            "uv sync"
        ) from exc
    return requests.post(*args, **kwargs)


def post_multipart_transcription(
    *,
    url: str,
    api_key: str,
    model: str,
    flac_path: Path,
    timeout_seconds: float,
) -> str:
    mime = mimetypes.guess_type(flac_path.name)[0] or "audio/flac"
    headers = {"Authorization": f"Bearer {api_key}"}
    data = {"model": model}

    with flac_path.open("rb") as flac_file:
        files = {"file": (flac_path.name, flac_file, mime)}
        response = requests_post(
            url,
            headers=headers,
            data=data,
            files=files,
            timeout=timeout_seconds,
        )
    response.raise_for_status()
    payload = response.json()
    text = payload.get("text")
    if not isinstance(text, str) or not text.strip():
        raise ValueError("Transcription response missing text.")
    return text.strip()
