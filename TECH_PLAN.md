# yada technical implementation plan

## Goals / non-goals
Goals:
- macOS native dictation app (direct download, notarized).
- minimal UI, fast capture -> transcribe -> rewrite -> insert at cursor.
- no audio/text stored on disk.
- predictable latency and clear failure modes.

Non-goals:
- multi-user accounts, cloud sync, or collaboration.
- offline transcription.
- heavy formatting or document editing features.

## Architecture overview
Process flow:
1) user triggers recording (hotkey or UI button).
2) audio capture in memory (AVAudioEngine -> PCM buffer).
3) send audio buffer to OpenAI transcription API.
4) send transcript to rewrite model.
5) insert rewritten text at cursor via Accessibility API.

Modules:
- App UI (SwiftUI): minimal window + status indicator.
- AudioCapture: AVAudioEngine pipeline, buffer management.
- OpenAIClient: HTTP client, models, retries, error mapping.
- RewritePipeline: orchestrates transcribe -> rewrite, cancellation.
- Inserter: Accessibility API insertion, fallback clipboard path.
- Settings: UserDefaults for non-sensitive config, Keychain for API key.
- Permissions: mic + accessibility prompts and guidance.

## UI and UX (SwiftUI)
Views:
- MainView: API key input (masked), mic selector, status, start/stop.
- PermissionsView (modal): steps for enabling mic + accessibility if denied.
- Minimal status indicator (recording/processing/error) with short text.

State machine:
- idle
- requestingPermissions
- recording
- transcribing
- rewriting
- inserting
- error (with recoverable action)

Hotkey:
- Global hotkey with configurable shortcut (e.g., Cmd+Shift+Space).

## Audio capture
- Use AVAudioEngine with AVAudioInputNode.
- Convert to 16-bit PCM, 16 kHz mono (or model-preferred format).
- Store in memory buffer only (no file IO).
- Max duration or manual stop.
- Support mic selection via AVAudioSession/AVCaptureDevice.

## OpenAI API integration
- Key storage in macOS Keychain.
- Minimal OpenAI client using URLSession.
- Models:
  - transcription: gpt-4o-transcribe
  - rewrite: gpt-5-mini
- Retry strategy: single retry on network timeouts; no retry on auth errors.
- Error handling: map errors to user-visible messages.
- Ensure API key never logged.

## Rewrite pipeline
- Run transcription and rewrite sequentially, cancellable.
- Add a simple system prompt for rewrite (punctuation, capitalization, minimal changes).
- Trim whitespace and normalize newline behavior before insertion.

## Cursor insertion
Primary method:
- Use Accessibility API (AXUIElement) to insert text at focused UI element.
Fallback:
- Use NSPasteboard temporarily with original clipboard restored after paste.
- No persistent storage; restore clipboard after insertion.

## Permissions handling
- Microphone: request via AVAudioSession.
- Accessibility: prompt and open System Settings if not granted.
- Show clear instructions and a retry button.

## Settings and configuration
- UserDefaults: selected mic, hotkey, last UI state.
- Keychain: OpenAI API key.

## Packaging and distribution
- Code signing and notarization for direct download.
- Provide a zip or dmg with an Applications folder shortcut.

## Testing and acceptance criteria
Functional tests:
- Permissions flow (mic + accessibility) on clean install.
- Dictation end-to-end in common apps (Notes, Safari, VS Code).
- Network failure and invalid API key handling.
- Clipboard fallback and restore correctness.

Acceptance criteria:
- Insertion success rate > 99% in target apps.
- No audio/text saved to disk.

## Milestones
1) Skeleton app + UI + settings + Keychain.
2) Audio capture + in-memory buffers.
3) OpenAI client + transcription.
4) Rewrite + insertion pipeline.
5) Permissions UX polish + error handling.
6) Packaging + notarization.
