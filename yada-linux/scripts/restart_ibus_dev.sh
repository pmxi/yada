#!/usr/bin/env bash
set -euo pipefail

LOCAL_COMPONENT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/ibus/component"

export IBUS_COMPONENT_PATH="$LOCAL_COMPONENT_DIR:/usr/share/ibus/component"

echo "IBUS_COMPONENT_PATH=$IBUS_COMPONENT_PATH"
echo "Restarting ibus-daemon with refreshed cache..."

# -d: daemonize, -r: replace running daemon, -x: start XIM (harmless on Wayland),
# --cache=refresh: force component re-scan.
ibus-daemon -drx -r --cache=refresh
