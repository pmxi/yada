#!/usr/bin/env python3
"""OpenAI-based dictation pipeline."""

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

OPENAI_TRANSCRIBE_URL = "https://api.openai.com/v1/audio/transcriptions"
OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses"
OPENAI_TRANSCRIBE_MODEL = "gpt-4o-transcribe"
OPENAI_REWRITE_MODEL = "gpt-5-mini"


def _parse_openai_responses_output(payload: dict[str, Any]) -> str:
    output_text = payload.get("output_text")
    if isinstance(output_text, str) and output_text.strip():
        return output_text.strip()

    parts: list[str] = []
    for item in payload.get("output", []):
        if not isinstance(item, dict) or item.get("type") != "message":
            continue
        for content in item.get("content", []):
            if not isinstance(content, dict):
                continue
            if content.get("type") == "output_text":
                text = content.get("text")
                if isinstance(text, str) and text:
                    parts.append(text)

    merged = "".join(parts).strip()
    if not merged:
        raise ValueError("No output text found in Responses API payload.")
    return merged


def _openai_rewrite(*, api_key: str, transcript: str, timeout_seconds: float) -> str:
    payload = {
        "model": OPENAI_REWRITE_MODEL,
        "input": transcript,
        "instructions": REWRITE_PROMPT,
        "reasoning": {"effort": "minimal"},
    }
    response = requests_post(
        OPENAI_RESPONSES_URL,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        json=payload,
        timeout=timeout_seconds,
    )
    response.raise_for_status()
    return _parse_openai_responses_output(response.json())


def run_openai_pipeline_from_flac(
    flac_path: str | Path,
    *,
    openai_api_key: str,
    timeout_seconds: float = 180.0,
) -> PipelineResult:
    if not openai_api_key:
        raise ValueError("Missing OpenAI API key.")
    flac = validate_flac_path(flac_path)

    start_total = time.perf_counter()

    start_asr = time.perf_counter()
    raw = post_multipart_transcription(
        url=OPENAI_TRANSCRIBE_URL,
        api_key=openai_api_key,
        model=OPENAI_TRANSCRIBE_MODEL,
        flac_path=flac,
        timeout_seconds=timeout_seconds,
    )
    asr_seconds = time.perf_counter() - start_asr

    start_rw = time.perf_counter()
    rewritten = _openai_rewrite(
        api_key=openai_api_key,
        transcript=raw,
        timeout_seconds=timeout_seconds,
    )
    rewrite_seconds = time.perf_counter() - start_rw

    return PipelineResult(
        pipeline="openai",
        flac_path=str(flac),
        asr_model=OPENAI_TRANSCRIBE_MODEL,
        rewrite_model=OPENAI_REWRITE_MODEL,
        raw_transcript=raw,
        rewritten_text=rewritten,
        transcribe_seconds=asr_seconds,
        rewrite_seconds=rewrite_seconds,
        total_seconds=time.perf_counter() - start_total,
    )
