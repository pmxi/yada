# Research Speech Pipelines

## Common Commands

Run these from `research/`:

```bash
cd research
uv sync
cp .env.example .env
uv run record_flac.py
uv run run_pipelines.py audio/mic-YYYYMMDD-HHMMSS.flac --pipelines openai groq
uv run record_and_run.py --pipelines openai groq
```

This setup is split into:
- core functionality modules (reusable logic)
- utility scripts (CLI entrypoints)

## Core modules

- `research/recording_core.py`
  - microphone recording logic
  - fixed audio format: `16000 Hz`, mono
- `research/openai_pipeline.py`
  - OpenAI pipeline: `gpt-4o-transcribe` -> `gpt-5-mini`
- `research/groq_pipeline.py`
  - Groq pipeline: `whisper-large-v3` -> `moonshotai/kimi-k2-instruct`
- `research/pipeline_runner_core.py`
  - pipeline selection + execution orchestration
- `research/pipeline_common.py`
  - shared types/helpers used by pipeline modules

## Utility scripts

- Record only (save FLAC):
  - `record_flac.py`
- Run pipelines on an existing FLAC:
  - `run_pipelines.py`
- Convenience: record FLAC and then run pipelines:
  - `record_and_run.py`

## Setup (uv)

Run from `research/`:

```bash
uv sync
```

## API keys via `.env`

Create `.env` in `research/`:

```bash
cp .env.example .env
```

Then set:

```env
OPENAI_API_KEY=your_openai_key
GROQ_API_KEY=your_groq_key
```

Pipeline utilities auto-load `.env` (current directory, then repo root).

## Default FLAC save location

By default, recordings are saved under:
- `audio/`

Example path:
- `audio/mic-20260208-123456.flac`

You can override with `--audio-dir` or `--output-file` (record-only utility).

## 1) Record a FLAC file and save it

```bash
uv run python record_flac.py
```

Optional:

```bash
uv run python record_flac.py --list-devices
uv run python record_flac.py --device "MacBook Pro Microphone"
uv run python record_flac.py --audio-dir audio
uv run python record_flac.py --output-file audio/custom-name.flac
```

## 2) Run pipelines on an existing FLAC

List pipeline ids:

```bash
uv run python run_pipelines.py --list-pipelines
```

Run:

```bash
uv run python run_pipelines.py audio/mic-20260208-123456.flac --pipelines openai groq
```

## 3) Convenience: record and run in one step

```bash
uv run python record_and_run.py --pipelines openai groq
```

Optional:

```bash
uv run python record_and_run.py --list-pipelines
uv run python record_and_run.py --list-devices
uv run python record_and_run.py --audio-dir audio
```

## Outputs

- FLAC files:
  - `audio/` by default
- JSON run artifacts:
  - `runs/`
