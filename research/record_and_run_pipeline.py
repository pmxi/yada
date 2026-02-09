#!/usr/bin/env python3
"""Utility: record a FLAC file, save it, then run selected pipelines."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import sys
from pathlib import Path

from env_utils import load_dotenv
from pipeline_runner_core import (
    PIPELINE_IDS,
    available_pipelines_text,
    resolve_pipelines,
    run_selected_pipelines,
)
from recording_core import (
    CHANNELS,
    SAMPLE_RATE,
    list_audio_devices,
    record_flac_to_file,
    timestamped_flac_path,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Record to FLAC and run speech pipeline(s).")
    parser.add_argument(
        "--pipelines",
        nargs="+",
        default=list(PIPELINE_IDS),
        help="Pipeline ids to run. Example: --pipelines openai groq",
    )
    parser.add_argument(
        "--list-pipelines",
        action="store_true",
        help="List available pipeline ids and exit.",
    )
    parser.add_argument(
        "--device",
        default=None,
        help="Optional input device name or index.",
    )
    parser.add_argument(
        "--list-devices",
        action="store_true",
        help="List available audio devices and exit.",
    )
    parser.add_argument(
        "--audio-dir",
        default="audio",
        help="Directory for saved FLAC files (default: ./audio).",
    )
    parser.add_argument(
        "--output-dir",
        default="runs",
        help="Directory for JSON run artifacts.",
    )
    parser.add_argument(
        "--timeout-seconds",
        type=float,
        default=180.0,
        help="Per-request timeout.",
    )
    return parser.parse_args()


def write_results_json(
    *,
    args: argparse.Namespace,
    selected: list[str],
    flac_path: Path,
    results: list[dict],
) -> Path:
    out_dir = Path(args.output_dir).expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    artifact = out_dir / f"record-and-run-{stamp}.json"
    payload = {
        "created_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "recorded_flac": str(flac_path),
        "pipelines": selected,
        "audio_format": {"sample_rate": SAMPLE_RATE, "channels": CHANNELS},
        "results": results,
    }
    artifact.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return artifact


def main() -> int:
    args = parse_args()
    if args.list_pipelines:
        print(available_pipelines_text())
        return 0
    if args.list_devices:
        print(list_audio_devices())
        return 0

    try:
        selected = resolve_pipelines(args.pipelines)
    except Exception as exc:  # noqa: BLE001
        print(f"Input error: {exc}", file=sys.stderr)
        return 2

    audio_dir = Path(args.audio_dir).expanduser().resolve()
    flac_path = timestamped_flac_path(audio_dir=audio_dir, prefix="mic")

    try:
        record_flac_to_file(output_file=flac_path, device=args.device)
    except Exception as exc:  # noqa: BLE001
        print(f"Recording failed: {exc}", file=sys.stderr)
        return 1

    project_root = Path(__file__).resolve().parents[1]
    load_dotenv([Path.cwd() / ".env", project_root / ".env"])
    openai_api_key = os.getenv("OPENAI_API_KEY", "")
    groq_api_key = os.getenv("GROQ_API_KEY", "")

    results, had_error = run_selected_pipelines(
        flac_path=flac_path,
        selected=selected,
        timeout_seconds=args.timeout_seconds,
        openai_api_key=openai_api_key,
        groq_api_key=groq_api_key,
        print_results=True,
    )

    artifact = write_results_json(args=args, selected=selected, flac_path=flac_path, results=results)
    print(f"\nSaved FLAC: {flac_path}")
    print(f"Saved artifact: {artifact}")
    return 1 if had_error else 0


if __name__ == "__main__":
    raise SystemExit(main())
