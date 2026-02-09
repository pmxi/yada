#!/usr/bin/env python3
"""Utility: run selected speech pipelines on a single FLAC file."""

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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run speech pipelines on one .flac file.")
    parser.add_argument("flac_file", nargs="?", help="Path to a .flac file.")
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
        "--timeout-seconds",
        type=float,
        default=180.0,
        help="Per-request timeout.",
    )
    parser.add_argument(
        "--output-dir",
        default="runs",
        help="Directory for JSON result artifacts.",
    )
    return parser.parse_args()


def write_results_json(args: argparse.Namespace, selected: list[str], results: list[dict]) -> Path:
    output_dir = Path(args.output_dir).expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    output_path = output_dir / f"pipeline-compare-{stamp}.json"
    payload = {
        "created_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "pipelines": selected,
        "source_flac": str(Path(args.flac_file).expanduser().resolve()),
        "results": results,
    }
    output_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return output_path


def main() -> int:
    args = parse_args()
    if args.list_pipelines:
        print(available_pipelines_text())
        return 0
    if not args.flac_file:
        print("flac_file is required unless --list-pipelines is used.", file=sys.stderr)
        return 2

    try:
        selected = resolve_pipelines(args.pipelines)
    except Exception as exc:  # noqa: BLE001
        print(f"Input error: {exc}", file=sys.stderr)
        return 2

    project_root = Path(__file__).resolve().parents[1]
    load_dotenv([Path.cwd() / ".env", project_root / ".env"])

    openai_api_key = os.getenv("OPENAI_API_KEY", "")
    groq_api_key = os.getenv("GROQ_API_KEY", "")
    results, had_error = run_selected_pipelines(
        flac_path=args.flac_file,
        selected=selected,
        timeout_seconds=args.timeout_seconds,
        openai_api_key=openai_api_key,
        groq_api_key=groq_api_key,
        print_results=True,
    )

    output_path = write_results_json(args, selected, results)
    print(f"\nSaved results: {output_path}")
    return 1 if had_error else 0


if __name__ == "__main__":
    raise SystemExit(main())
