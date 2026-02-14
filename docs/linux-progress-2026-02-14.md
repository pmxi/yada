# Linux (Ubuntu GNOME Wayland) Progress Notes (2026-02-14)

This doc captures what we built today for a Wayland-first Linux port of yada, what decisions were made, what works, what does not yet exist, and how to run/debug it.

## Goal

Build a new Linux version of yada (separate from the macOS app) that works on Ubuntu 24 + GNOME + Wayland:

- Trigger dictation via hotkey
- Record mic audio in-memory
- Transcribe with OpenAI
- Rewrite with OpenAI (punctuation/grammar fixes)
- Insert the rewritten text into the currently focused app

Wayland support is non-negotiable.

## Key Decisions

- Wayland text insertion: use an IBus input method engine (reliable on Wayland).
  - Rationale: GNOME Wayland restricts global hotkeys + synthetic typing in arbitrary apps.
  - This keeps insertion "with the grain" of the platform.

- Codebase: new Rust workspace under `yada-linux/`.
  - Rationale: isolate Linux work; do not entangle with macOS app/Xcode project.

- Current IBus engine implementation: Python + GI (`python3-gi`, `python3-ibus-1.0`).
  - D-Bus calls use the `gdbus` CLI (minimal deps for now).
  - Rationale: move most logic into the Rust daemon; keep the engine small.

- Hotkey behavior: toggle mode on `Ctrl+Alt+Space`.
  - Engine ignores key-release events and debounces to avoid double-toggle on press+release.

- Audio capture: Rust `cpal` (ALSA backend on Ubuntu).
  - Requires `libasound2-dev` + `pkg-config`.

- Secrets: not implemented yet.
  - For now the daemon reads `YADA_OPENAI_API_KEY` from the environment.
  - Future: Secret Service / GNOME Keyring + UI.

## What Exists Now (Working)

### Linux workspace scaffold

- `yada-linux/` Rust workspace with crates:
  - `yada-linux/crates/yada-core` (shared functionality)
  - `yada-linux/crates/yada-daemon` (D-Bus service; owns recording + API)
  - `yada-linux/crates/yada-settings-ui` (placeholder)

### D-Bus daemon

- Service name: `dev.yada.Linux`
- Object path: `/dev/yada/Linux`
- Interface: `dev.yada.Linux`
- Methods:
  - `Ping -> "pong"`
  - `Start -> ()` (starts audio capture)
  - `Stop -> "<rewritten text>"` (stops capture, calls OpenAI, returns text)

Implementation notes:

- Audio capture runs in a dedicated thread (because `cpal::Stream` is not `Send + Sync`, and zbus interfaces require `Send + Sync`).
- `Stop` returns a D-Bus error if the OpenAI key is missing or API calls fail.

### IBus engine

- Engine name: `yada`
- Default trigger: `Ctrl+Alt+Space`
- UI:
  - On Start: shows `Yada: Listening...`
  - On Stop: shows `Yada: Processing...` until the daemon returns, then commits text

Implementation notes:

- D-Bus calls are executed in a background thread so the key event handler doesn’t block.
- Trigger handling:
  - Ignores release events (`IBus.ModifierType.RELEASE_MASK`)
  - Debounces to avoid immediate double-toggle

### OpenAI pipeline

- Transcription endpoint: `POST /v1/audio/transcriptions` (multipart WAV)
- Rewrite endpoint: `POST /v1/responses`
- Defaults (in `yada-linux/crates/yada-core/src/lib.rs`):
  - `DEFAULT_TRANSCRIBE_MODEL = "gpt-4o-transcribe"`
  - `DEFAULT_REWRITE_MODEL = "gpt-5-mini"`
  - `DEFAULT_REWRITE_PROMPT = "Rewrite the text with correct punctuation and capitalization..."`

### Config

- Config file location: XDG config dir from `directories::ProjectDirs`:
  - Typically `~/.config/yada-linux/config.toml`
- Current behavior: daemon loads config if present, otherwise uses defaults.

## What Is Not Done Yet

- No settings UI (`yada-linux/crates/yada-settings-ui` is a placeholder).
- No Secret Service / GNOME Keyring integration.
  - API key must be supplied via `YADA_OPENAI_API_KEY`.
- No device selection (mic selection, sampling rate policy, etc.).
- No packaging/distribution (deb, systemd user service, etc.).
- No robust error feedback in the IBus UI beyond basic indicator behavior.
- Hold-to-talk mode is not implemented (toggle only).

## Dev Setup (Ubuntu 24.04 GNOME)

Packages:

```bash
sudo apt update
sudo apt install -y \
  ibus python3-gi python3-ibus-1.0 \
  libasound2-dev pkg-config
```

Optional (for future settings UI work):

```bash
sudo apt install -y \
  libgtk-4-1 gir1.2-gtk-4.0 \
  libadwaita-1-0 gir1.2-adw-1
```

Rust toolchain is required.

## How To Run (Dev)

### 1) Run the daemon

From the repo root:

```bash
cd yada-linux
export YADA_OPENAI_API_KEY="..."
cargo run -p yada-daemon
```

Sanity check D-Bus:

```bash
gdbus call --session \
  --dest dev.yada.Linux \
  --object-path /dev/yada/Linux \
  --method dev.yada.Linux.Ping
```

### 2) Install the IBus engine (dev)

```bash
cd yada-linux
./scripts/install_dev_ibus.sh
```

This installs:

- Component XML: `~/.local/share/ibus/component/yada-linux.xml`
- Engine wrapper/script: `~/.local/share/yada-linux/ibus-engine/`

### 3) Restart IBus so it discovers the local component

```bash
cd yada-linux
./scripts/restart_ibus_dev.sh
```

Note: this sets:

```bash
IBUS_COMPONENT_PATH="$HOME/.local/share/ibus/component:/usr/share/ibus/component"
```

### 4) Enable/select the input source

GNOME Settings:

- Settings -> Keyboard -> Input Sources
- Add "Yada"
- Select it

CLI quick switch:

```bash
ibus engine yada
```

Check current engine:

```bash
ibus engine
```

### 5) Use it

- Press `Ctrl+Alt+Space` to start recording (shows `Yada: Listening...`).
- Press `Ctrl+Alt+Space` again to stop (shows `Yada: Processing...`).
- The rewritten text is committed into the focused app.

## Debugging

### Engine key/trigger debugging

The engine writes a simple log:

```bash
cat ~/.cache/yada-linux/ibus-engine.log
```

If the log is empty when you press the hotkey, the key events aren’t reaching the IBus engine (often: the active input source is not Yada).

### Common gotcha: input source switching back

If you restart `ibus-daemon`, GNOME can fall back to the default input source (`xkb:us::eng`).

- Avoid restarting IBus unless you’re reinstalling the component.
- Use `ibus engine yada` or GNOME Settings to switch back.

### Audio capture warnings

You may see:

`cpal stream error: A backend-specific error has occurred: alsa::poll() spuriously returned`

This comes from ALSA/`cpal` and can be transient. If it repeats frequently and recordings are empty/inconsistent, we should make capture errors propagate to the daemon and show a clear IBus error indicator.

## Code Pointers

- Workspace: `yada-linux/Cargo.toml`
- Daemon: `yada-linux/crates/yada-daemon/src/main.rs`
- Core:
  - WAV encode: `yada-linux/crates/yada-core/src/audio.rs`
  - Audio capture: `yada-linux/crates/yada-core/src/audio_capture.rs`
  - OpenAI client: `yada-linux/crates/yada-core/src/openai.rs`
  - Config: `yada-linux/crates/yada-core/src/config.rs`
- IBus engine: `yada-linux/ibus-engine/yada_engine.py`
- Scripts: `yada-linux/scripts/install_dev_ibus.sh`, `yada-linux/scripts/restart_ibus_dev.sh`

## Next Steps

- Implement Secret Service / GNOME Keyring storage + a minimal settings UI.
- Improve capture resiliency (handle ALSA/pipewire hiccups; explicit errors surfaced to the IBus UI).
- Add hold-to-talk mode (likely separate hotkey or reliable release-event handling).
- Add systemd user service for the daemon.
- Package/distribute (likely deb first; IBus integration needs careful install/uninstall).
