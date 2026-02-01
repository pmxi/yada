# yada

Yet another dictation app for macOS.

yada records audio in memory, transcribes with OpenAI, rewrites for punctuation/casing, and inserts text at the current cursor. It is designed for direct download (not App Store), minimal UI, and clean code.

Demo (click to watch):



https://github.com/user-attachments/assets/f7a67c6e-a14d-4b1e-8ba7-b98a07740561



## Install (macOS)
1. Download the latest `yada-*-mac.zip` from GitHub Releases.
2. Double-click the zip to unzip it.
3. Drag `yada.app` into your **Applications** folder.
4. First launch: right-click `yada.app` → **Open** → **Open**.
5. If macOS blocks it, go to **System Settings → Privacy & Security** and click **Open Anyway**.

## First run
1. Open **yada** from Applications.
2. Enter your OpenAI API key and click **Save**.
3. Grant **Microphone** and **Accessibility** permissions when prompted.
4. Press the global hotkey to start/stop dictation (default: Cmd+grave).

## Build from source (developers)
1. Open `yada/yada.xcodeproj` in Xcode.
2. Build and run the `yada` target.
3. Enter your OpenAI API key and click Save.
4. Grant Microphone and Accessibility permissions when prompted.
5. Press the global hotkey to start/stop dictation (default: Cmd+grave).

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

