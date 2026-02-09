#!/usr/bin/env python3
"""Core functionality to run selected speech pipelines on FLAC files."""

from __future__ import annotations

import sys
from dataclasses import asdict
from pathlib import Path

from groq_pipeline import run_groq_pipeline_from_flac
from openai_pipeline import run_openai_pipeline_from_flac
from pipeline_common import PipelineResult

PIPELINE_IDS = ("openai", "groq")
PIPELINE_DESCRIPTIONS = {
    "openai": "app-like OpenAI pipeline (gpt-4o-transcribe -> gpt-5-mini)",
    "groq": "Groq pipeline (whisper-large-v3 -> moonshotai/kimi-k2-instruct)",
}


def resolve_pipelines(selected: list[str]) -> list[str]:
    cleaned = [item.strip().lower() for item in selected if item.strip()]
    unknown = [item for item in cleaned if item not in PIPELINE_IDS]
    if unknown:
        raise ValueError(f"Unknown pipeline id(s): {', '.join(unknown)}")

    deduped: list[str] = []
    for item in cleaned:
        if item not in deduped:
            deduped.append(item)
    if not deduped:
        raise ValueError("No pipelines selected.")
    return deduped


def available_pipelines_text() -> str:
    lines = ["Available pipelines:"]
    for pipeline in PIPELINE_IDS:
        lines.append(f"- {pipeline}: {PIPELINE_DESCRIPTIONS[pipeline]}")
    return "\n".join(lines)


def print_pipeline_result(result: PipelineResult) -> None:
    print(f"\n[{result.pipeline}] {Path(result.flac_path).name}")
    print(f"  asr_model: {result.asr_model}")
    print(f"  rewrite_model: {result.rewrite_model}")
    print(
        f"  timing: asr={result.transcribe_seconds:.2f}s "
        f"rewrite={result.rewrite_seconds:.2f}s total={result.total_seconds:.2f}s"
    )
    print(f"  raw: {result.raw_transcript}")
    print(f"  rewritten: {result.rewritten_text}")


def run_selected_pipelines(
    *,
    flac_path: str | Path,
    selected: list[str],
    timeout_seconds: float,
    openai_api_key: str,
    groq_api_key: str,
    print_results: bool = True,
) -> tuple[list[dict], bool]:
    had_error = False
    results: list[dict] = []
    flac = str(Path(flac_path).expanduser())

    for pipeline in selected:
        if pipeline == "openai":
            try:
                result = run_openai_pipeline_from_flac(
                    flac,
                    openai_api_key=openai_api_key,
                    timeout_seconds=timeout_seconds,
                )
                if print_results:
                    print_pipeline_result(result)
                results.append(asdict(result))
            except Exception as exc:  # noqa: BLE001
                had_error = True
                print(f"{Path(flac).name} [openai] failed: {exc}", file=sys.stderr)
                results.append({"pipeline": "openai", "flac_path": flac, "error": str(exc)})

        if pipeline == "groq":
            try:
                result = run_groq_pipeline_from_flac(
                    flac,
                    groq_api_key=groq_api_key,
                    timeout_seconds=timeout_seconds,
                )
                if print_results:
                    print_pipeline_result(result)
                results.append(asdict(result))
            except Exception as exc:  # noqa: BLE001
                had_error = True
                print(f"{Path(flac).name} [groq] failed: {exc}", file=sys.stderr)
                results.append({"pipeline": "groq", "flac_path": flac, "error": str(exc)})

    return results, had_error
