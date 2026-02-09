#!/usr/bin/env python3
"""Utility: record microphone input to a saved FLAC file."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from recording_core import (
    CHANNELS,
    SAMPLE_RATE,
    list_audio_devices,
    record_flac_to_file,
    timestamped_flac_path,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Record microphone audio to a FLAC file.")
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
        "--output-file",
        default=None,
        help="Optional full FLAC output path. Overrides --audio-dir timestamp naming.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.list_devices:
        print(list_audio_devices())
        return 0

    if args.output_file:
        output_file = Path(args.output_file).expanduser().resolve()
    else:
        audio_dir = Path(args.audio_dir).expanduser().resolve()
        output_file = timestamped_flac_path(audio_dir=audio_dir, prefix="mic")

    try:
        record_flac_to_file(output_file=output_file, device=args.device)
    except Exception as exc:  # noqa: BLE001
        print(f"Recording failed: {exc}", file=sys.stderr)
        return 1

    print(f"\nSaved FLAC: {output_file}")
    print(f"Audio format: {SAMPLE_RATE} Hz, {CHANNELS} channel")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
