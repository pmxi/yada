# yada-linux

Wayland-first Linux build of yada for Ubuntu GNOME.

This implementation uses an IBus input method engine for reliable text insertion on Wayland.

## Dev setup (Ubuntu 24.04 GNOME)

Prereqs (packages):

- `ibus`, `python3-gi`, `python3-ibus-1.0`
- `libgtk-4-1`, `gir1.2-gtk-4.0`, `libadwaita-1-0`, `gir1.2-adw-1`

Rust toolchain is required for the daemon and settings UI.

## Run (dev)

1) Start the daemon:

```bash
cd yada-linux
cargo run -p yada-daemon
```

2) Install the IBus engine (dev):

```bash
./scripts/install_dev_ibus.sh
```

3) Restart ibus to load the dev component:

```bash
./scripts/restart_ibus_dev.sh
```

4) In GNOME Settings -> Keyboard -> Input Sources:

- Add the "Yada" input source.
- Select it.

5) Use the dictation trigger:

- Default: `Ctrl+Alt+Space` (toggle mode)

## API key

Dev override:

- `YADA_OPENAI_API_KEY` (environment variable)

The settings UI will store the API key in Secret Service (GNOME Keyring).
