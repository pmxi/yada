# Repository Guidelines

## Project Structure & Module Organization
- `yada/` holds the Xcode project and sources; the app code lives in `yada/yada/`.
- Core folders: `App/`, `UI/`, `ViewModel/`, `Services/`, `Models/`, `Utils/`.
- Assets and previews: `yada/yada/Assets.xcassets`, `yada/yada/Preview Content/`.
- Tests: `yada/yadaTests/` (unit) and `yada/yadaUITests/` (UI).
- Documentation: `docs/` (architecture, development, troubleshooting).

## Build, Test, and Development Commands
Build from CLI:
```bash
xcodebuild -project yada/yada.xcodeproj -scheme yada
```
When multiple Xcodes are installed:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project yada/yada.xcodeproj -scheme yada
```
Run locally by opening `yada/yada.xcodeproj` in Xcode and running the `yada` target.

Run tests (macOS destination):
```bash
xcodebuild -project yada/yada.xcodeproj -scheme yada -destination 'platform=macOS' test
```

## Coding Style & Naming Conventions
- Follow Swift API Design Guidelines and Xcode’s default formatting (4‑space indentation).
- Types use `PascalCase`, methods/vars use `camelCase`, and files generally match the primary type name.
- Keep UI in `UI/`, app orchestration in `ViewModel/`, and system/integration logic in `Services/`.

## Testing Guidelines
- XCTest is used for unit and UI tests; current tests are scaffold examples.
- Name tests with the `test...` prefix and place new coverage in the appropriate target (`yadaTests` or `yadaUITests`).

## Commit & Pull Request Guidelines
- Commit messages are short, imperative summaries (e.g., "Update app behavior and UI").
- PRs should include a concise description, steps to test, and screenshots for UI changes. Call out permission or privacy-impacting changes explicitly.

## Security & Configuration Tips
- API keys are stored in Keychain (`dev.yada` / `openai-api-key`); do not log or commit secrets.
- Debug logging can be enabled with `YADA_OPENAI_DEBUG=1`; logs write to `~/Library/Logs/yada-debug/` (Debug builds only). Use `YADA_OPENAI_DEBUG_AUTH=1` only when absolutely necessary.
