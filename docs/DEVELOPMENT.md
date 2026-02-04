# Development

## Requirements
- macOS 14.5 (deployment target).
- Xcode (project created with current Xcode defaults).

## Open the project
Open `yada/yada.xcodeproj` in Xcode.

## Build (CLI)
```
xcodebuild -project yada/yada.xcodeproj -scheme yada
```
If you have multiple Xcode versions installed, set:
```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project yada/yada.xcodeproj -scheme yada
```

## Run
- Run the `yada` target from Xcode.
- Enter your OpenAI API key and click Save.
- Grant Microphone and Accessibility permissions.
- Use the global hotkey to start/stop.

## Configuration
- API key storage: Keychain service `dev.yada`, account `openai-api-key`.
- UserDefaults keys:
  - `selectedInputDeviceUID`: selected microphone.
  - `hotKeyKeyCode`, `hotKeyModifiers`: hotkey binding.
  - `hotKeyMode`: `"toggle"` or `"hold"` (default: `"toggle"`).
  - `rewritePrompt`: custom GPT rewrite instructions (default provided if unset).
- Default hotkey: Cmd+grave (backtick key).

## Debugging
- Enable full OpenAI request/response logging (DEBUG builds only) by setting `YADA_OPENAI_DEBUG=1`.
- Logs are written to `~/Library/Logs/yada-debug/` with one request/response pair per call.
- To include the Authorization header in logs, also set `YADA_OPENAI_DEBUG_AUTH=1`.

## Local secrets
- The file `openaikey_SECRET` is a local, untracked scratch file for your own use.
- The app does not read that file; API key is set via UI and stored in Keychain.

## Project structure
- App source: `yada/yada/`
- Tests: `yada/yadaTests/`, `yada/yadaUITests/` (scaffold only).
- Entitlements: `yada/yada/yada.entitlements` (currently empty).

## Distribution notes
- Intended for direct download (not App Store).
- Codesigning and notarization are still to be done for release builds.
