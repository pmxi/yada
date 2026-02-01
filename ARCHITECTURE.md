# Architecture

## High-level flow
1) User triggers start/stop (global hotkey or UI button).
2) Audio is captured in memory (AVAudioEngine input tap).
3) Audio is converted to 16 kHz, 16-bit, mono PCM.
4) PCM is wrapped in a WAV header in memory.
5) WAV is sent to OpenAI for transcription.
6) Transcript is sent to OpenAI for rewrite.
7) Rewritten text is inserted at the current cursor.

## Core modules
- `yada/yada/App/`
  - `yadaApp.swift`: SwiftUI app entry.
  - `AppDelegate.swift`: App lifecycle hooks.
- `yada/yada/ViewModel/`
  - `AppViewModel.swift`: Orchestrates state machine, pipeline, and UI bindings.
- `yada/yada/UI/`
  - `ContentView.swift`: Minimal UI (status, API key, mic picker, hotkey, actions).
  - `HotKeyRecorder.swift`: In-app recorder for configuring hotkey.
- `yada/yada/Services/`
  - `AudioCapture.swift`: AVAudioEngine capture + format conversion.
  - `AudioDeviceManager.swift`: CoreAudio device listing + default input selection.
  - `OpenAIClient.swift`: URLSession client for transcription + rewrite.
  - `TextInserter.swift`: Accessibility insertion + clipboard fallback.
  - `HotKeyManager.swift`: Global hotkey registration via Carbon.
  - `Permissions.swift`: Microphone + Accessibility request helpers.
  - `KeychainStore.swift`: API key storage (service `dev.yada`).
  - `SettingsStore.swift`: UserDefaults for hotkey and selected mic.
- `yada/yada/Models/`
  - `AppStatus.swift`, `AlertItem.swift`, `CapturedAudio.swift`, `AudioInputDevice.swift`, `HotKey.swift`, `OpenAIModels.swift`.
- `yada/yada/Utils/`
  - `WavEncoder.swift`, `MultipartFormData.swift`, `Data+Append.swift`, `KeyCodeTranslator.swift`.

## State machine
`AppStatus` drives UI and pipeline progress:
- idle
- recording
- transcribing
- rewriting
- inserting
- error

`AppViewModel.toggleRecording()` transitions between idle/recording and stops into the pipeline.

## Hotkey behavior
- Registered globally via Carbon `RegisterEventHotKey`.
- Default: Cmd+grave (backtick key).
- Hotkey settings stored in UserDefaults and registered on app launch.
- HotKey recorder requires at least one modifier to avoid collisions.

## Audio format
- Captured at input device native format, converted to:
  - 16 kHz
  - 16-bit PCM
  - mono
- WAV header assembled in `WavEncoder.encode(...)`.

## OpenAI usage
- Transcription: POST `/v1/audio/transcriptions` with `gpt-4o-transcribe`.
- Rewrite: POST `/v1/responses` with `gpt-5-mini` and a short instruction.
- Errors are mapped to user-visible alerts.

## Text insertion
1) Attempt Accessibility insertion via `AXUIElementSetAttributeValue` on focused element.
2) If that fails, use pasteboard + synthetic Cmd+V and then restore the previous clipboard.

## Storage and persistence
- API key in Keychain (`dev.yada` / `openai-api-key`).
- Selected microphone + hotkey stored in UserDefaults.
- No audio or text persisted to disk by the app.
