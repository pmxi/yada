(AI written)


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
- Follow Swift API Design Guidelines and Xcode's default formatting (4‑space indentation).
- Types use `PascalCase`, methods/vars use `camelCase`, and files generally match the primary type name.
- Keep UI in `UI/`, app orchestration in `ViewModel/`, and system/integration logic in `Services/`.

## Commit & Pull Request Guidelines
- Commit messages are short, imperative summaries (e.g., "Update app behavior and UI").

The .xcodeproj bundle contains files that Xcode mutates automatically.
Namely: project.pbxproj and .xcscheme
These files mix configuration (which must be versioned) with IDE state (which ideally
wouldn't be). This is a known Xcode quirk. When these files show changes, just
commit them without concern. The diffs are often noisy but harmless.

