#!/usr/bin/env python3
"""Core microphone recording functionality for FLAC capture."""

from __future__ import annotations

import datetime as dt
import sys
from pathlib import Path

SAMPLE_RATE = 16000
CHANNELS = 1


def timestamped_flac_path(audio_dir: Path, prefix: str = "mic") -> Path:
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    return audio_dir / f"{prefix}-{stamp}.flac"


def load_audio_libs():
    try:
        import numpy as np
        import sounddevice as sd
        import soundfile as sf

        return np, sd, sf
    except Exception as exc:  # noqa: BLE001
        raise RuntimeError(
            "Mic recording requires `numpy`, `sounddevice`, and `soundfile`. "
            "Install with: uv sync"
        ) from exc


def list_audio_devices() -> str:
    _, sd, _ = load_audio_libs()
    return str(sd.query_devices())


def record_flac_to_file(*, output_file: Path, device: str | int | None = None) -> Path:
    np, sd, sf = load_audio_libs()
    output_file.parent.mkdir(parents=True, exist_ok=True)

    print(f"Recording to: {output_file}")
    print(f"Audio format: {SAMPLE_RATE} Hz, mono")
    print("Press Enter to start recording.")
    input()
    print("Recording... Press Enter to stop.")
    chunks = []

    def callback(indata, _frames, _time, status):
        if status:
            print(f"Audio status: {status}", file=sys.stderr)
        chunks.append(indata.copy())

    with sd.InputStream(
        samplerate=SAMPLE_RATE,
        channels=CHANNELS,
        dtype="float32",
        device=device,
        callback=callback,
    ):
        input()

    if not chunks:
        raise RuntimeError("No audio captured from microphone.")

    audio = np.concatenate(chunks, axis=0)
    sf.write(str(output_file), audio, SAMPLE_RATE, format="FLAC", subtype="PCM_16")
    return output_file
