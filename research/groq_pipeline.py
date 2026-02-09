#!/usr/bin/env python3
"""Groq-based dictation pipeline."""

from __future__ import annotations

import time
from pathlib import Path
from typing import Any

from pipeline_common import (
    PipelineResult,
    REWRITE_PROMPT,
    post_multipart_transcription,
    requests_post,
    validate_flac_path,
)

GROQ_TRANSCRIBE_URL = "https://api.groq.com/openai/v1/audio/transcriptions"
GROQ_CHAT_URL = "https://api.groq.com/openai/v1/chat/completions"
GROQ_TRANSCRIBE_MODEL = "whisper-large-v3"
GROQ_REWRITE_MODEL = "moonshotai/kimi-k2-instruct"
GROQ_REWRITE_TEMPERATURE = 0.0


def _parse_chat_completion_output(payload: dict[str, Any]) -> str:
    choices = payload.get("choices", [])
    if not isinstance(choices, list) or not choices:
        raise ValueError("No choices in chat completion payload.")
    message = choices[0].get("message", {})
    if not isinstance(message, dict):
        raise ValueError("Invalid message in chat completion payload.")
    content = message.get("content")
    if isinstance(content, str):
        text = content.strip()
        if text:
            return text
    if isinstance(content, list):
        parts: list[str] = []
        for item in content:
            if isinstance(item, dict):
                text = item.get("text")
                if isinstance(text, str) and text:
                    parts.append(text)
        merged = "".join(parts).strip()
        if merged:
            return merged
    raise ValueError("Unable to parse chat completion text.")


def _groq_rewrite(*, api_key: str, transcript: str, timeout_seconds: float) -> str:
    payload = {
        "model": GROQ_REWRITE_MODEL,
        "temperature": GROQ_REWRITE_TEMPERATURE,
        "messages": [
            {"role": "system", "content": REWRITE_PROMPT},
            {"role": "user", "content": transcript},
        ],
    }
    response = requests_post(
        GROQ_CHAT_URL,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        json=payload,
        timeout=timeout_seconds,
    )
    response.raise_for_status()
    return _parse_chat_completion_output(response.json())


def run_groq_pipeline_from_flac(
    flac_path: str | Path,
    *,
    groq_api_key: str,
    timeout_seconds: float = 180.0,
) -> PipelineResult:
    if not groq_api_key:
        raise ValueError("Missing Groq API key.")
    flac = validate_flac_path(flac_path)

    start_total = time.perf_counter()

    start_asr = time.perf_counter()
    raw = post_multipart_transcription(
        url=GROQ_TRANSCRIBE_URL,
        api_key=groq_api_key,
        model=GROQ_TRANSCRIBE_MODEL,
        flac_path=flac,
        timeout_seconds=timeout_seconds,
    )
    asr_seconds = time.perf_counter() - start_asr

    start_rw = time.perf_counter()
    rewritten = _groq_rewrite(
        api_key=groq_api_key,
        transcript=raw,
        timeout_seconds=timeout_seconds,
    )
    rewrite_seconds = time.perf_counter() - start_rw

    return PipelineResult(
        pipeline="groq",
        flac_path=str(flac),
        asr_model=GROQ_TRANSCRIBE_MODEL,
        rewrite_model=GROQ_REWRITE_MODEL,
        raw_transcript=raw,
        rewritten_text=rewritten,
        transcribe_seconds=asr_seconds,
        rewrite_seconds=rewrite_seconds,
        total_seconds=time.perf_counter() - start_total,
    )
