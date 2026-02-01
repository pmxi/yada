# yada

Yet another dictation app for macOS.

yada records audio in memory, transcribes with OpenAI, rewrites for punctuation/casing, and inserts text at the current cursor. It is designed for direct download (not App Store), minimal UI, and clean code.

Demo:
```
I said: Google DeepMind CEO Demis Hassabis: AI's Next Breakthroughs, AGI Timeline, and Google's AI Glasses Bet
yada wrote: Google DeepMind CEO Demis Hassabis: AI's Next Breakthroughs, AGI Timeline, and Google's AI Glasses Bet
Apple Dictation wrote: Google deep mind, CEO deceives AI next breakthrough AGI timeline and Google AI class bet
```

## Quick start
- Open `yada/yada.xcodeproj` in Xcode.
- Build and run the `yada` target.
- Enter your OpenAI API key and click Save.
- Grant Microphone and Accessibility permissions when prompted.
- Press the global hotkey to start/stop dictation (default: Cmd+grave).

## Features
- Global start/stop hotkey (configurable).
- Mic selection (sets system default input device).
- In-memory audio capture (no audio/text saved to disk).
- OpenAI transcription + rewrite pipeline.
- Accessibility-based insertion with clipboard fallback.

## Defaults
- Transcription model: `gpt-4o-transcribe`
- Rewrite model: `gpt-5-mini`
- Hotkey: Cmd+grave (backtick key) with at least one modifier required

## Project layout
- `yada/`: Xcode project directory.
- `yada/yada/`: application source.
- `docs/`: documentation.

## Docs
- `docs/ARCHITECTURE.md`: module breakdown and data flow.
- `docs/DEVELOPMENT.md`: build/run notes and configuration.
- `docs/SECURITY_PRIVACY.md`: data handling and permissions.
- `docs/TROUBLESHOOTING.md`: common failures and fixes.
- `docs/DOCS.md`: documentation index.
- `docs/PLAN.md`: product intent and principles.
- `docs/TECH_PLAN.md`: implementation plan.
