#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_REL="yada/yada.xcodeproj"
SCHEME="yada"
CONFIG="Release"
OUT_DIR="$ROOT_DIR/builds"
NO_BUILD=0

usage() {
  cat <<'USAGE'
Usage: scripts/package_release_zip.sh [options]

Builds a Release app and creates a versioned zip for GitHub Releases.

Options:
  -p, --project <path>   Xcode project path (default: yada/yada.xcodeproj)
  -s, --scheme <name>    Scheme name (default: yada)
  -c, --config <name>    Build configuration (default: Release)
  -o, --out <dir>        Output directory (default: builds/)
  --no-build             Skip the build step (assumes app already built)
  -h, --help             Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--project)
      PROJECT_REL="$2"
      shift 2
      ;;
    -s|--scheme)
      SCHEME="$2"
      shift 2
      ;;
    -c|--config)
      CONFIG="$2"
      shift 2
      ;;
    -o|--out)
      OUT_DIR="$2"
      shift 2
      ;;
    --no-build)
      NO_BUILD=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

PROJECT_PATH="$PROJECT_REL"
if [[ "$PROJECT_PATH" != /* ]]; then
  PROJECT_PATH="$ROOT_DIR/$PROJECT_REL"
fi

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Project not found: $PROJECT_PATH"
  exit 1
fi

if [[ "$NO_BUILD" -eq 0 ]]; then
  xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME" -configuration "$CONFIG" build
fi

BUILD_SETTINGS="$(xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME" -configuration "$CONFIG" -showBuildSettings)"
TARGET_BUILD_DIR="$(printf "%s\n" "$BUILD_SETTINGS" | awk -F ' = ' '/TARGET_BUILD_DIR/ {print $2; exit}')"
FULL_PRODUCT_NAME="$(printf "%s\n" "$BUILD_SETTINGS" | awk -F ' = ' '/FULL_PRODUCT_NAME/ {print $2; exit}')"

if [[ -z "$TARGET_BUILD_DIR" || -z "$FULL_PRODUCT_NAME" ]]; then
  echo "Failed to locate build output path."
  exit 1
fi

APP_PATH="$TARGET_BUILD_DIR/$FULL_PRODUCT_NAME"
if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found at: $APP_PATH"
  exit 1
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"
VERSION=""
if [[ -f "$INFO_PLIST" ]]; then
  VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || true)"
fi
if [[ -z "$VERSION" ]]; then
  VERSION="0.0.0"
fi

ZIP_NAME="yada-v${VERSION}-mac.zip"
mkdir -p "$OUT_DIR"
OUT_PATH="$OUT_DIR/$ZIP_NAME"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$OUT_PATH"

echo "Created: $OUT_PATH"
