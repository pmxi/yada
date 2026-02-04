# Roadmap

Future features and improvements.

## Planned

### Fn-only hotkey support
Allow using just the Fn key as the hotkey trigger (like Wispr Flow).

**Why not now:** The current implementation uses Carbon's `RegisterEventHotKey` API, which requires a keyCode + modifiers. The Fn key has no keyCode — it only appears in modifier flags.

**Implementation:** Requires `CGEventTap` with `kCGEventFlagsChanged` to globally monitor modifier state. This is a separate code path from the current hotkey system. Accessibility permissions are already required, so no new permissions needed.
