#!/usr/bin/env python3
"""Lightweight .env loader for research scripts."""

from __future__ import annotations

import os
from pathlib import Path


def _strip_quotes(value: str) -> str:
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        return value[1:-1]
    return value


def load_dotenv(paths: list[Path]) -> Path | None:
    """Load KEY=VALUE pairs from the first existing .env file.

    Existing environment variables are not overwritten.
    """
    for path in paths:
        if not path.exists() or not path.is_file():
            continue
        for line in path.read_text(encoding="utf-8").splitlines():
            item = line.strip()
            if not item or item.startswith("#"):
                continue
            if item.startswith("export "):
                item = item[len("export ") :].strip()
            if "=" not in item:
                continue
            key, value = item.split("=", 1)
            key = key.strip()
            value = _strip_quotes(value.strip())
            if key and key not in os.environ:
                os.environ[key] = value
        return path
    return None
