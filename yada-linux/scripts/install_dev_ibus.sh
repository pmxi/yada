#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE_DIR="$ROOT_DIR/ibus-engine"

PREFIX_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
TARGET_COMPONENT_DIR="$PREFIX_DIR/ibus/component"
TARGET_ENGINE_DIR="$PREFIX_DIR/yada-linux/ibus-engine"
TARGET_ENGINE_EXEC="$TARGET_ENGINE_DIR/yada-engine"

mkdir -p "$TARGET_COMPONENT_DIR"
mkdir -p "$TARGET_ENGINE_DIR"

install -m 0755 "$ENGINE_DIR/yada_engine.py" "$TARGET_ENGINE_DIR/yada_engine.py"

cat >"$TARGET_ENGINE_EXEC" <<EOF
#!/usr/bin/env bash
exec /usr/bin/env python3 "$TARGET_ENGINE_DIR/yada_engine.py"
EOF
chmod 0755 "$TARGET_ENGINE_EXEC"

ENGINE_XML="$TARGET_COMPONENT_DIR/yada-linux.xml"
sed "s|@@EXEC@@|$TARGET_ENGINE_EXEC|g" "$ENGINE_DIR/yada-linux.xml.in" >"$ENGINE_XML"

echo "Installed IBus component to: $TARGET_COMPONENT_DIR/yada-linux.xml"
echo "Installed engine script to: $TARGET_ENGINE_DIR/yada_engine.py"
echo "Installed engine wrapper to: $TARGET_ENGINE_EXEC"
echo
echo "Next steps:"
echo "- Restart ibus: ibus restart"
echo "- Add input source: Settings -> Keyboard -> Input Sources -> Add -> Yada"
