#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="VoiceFlick"
BUNDLE_ID="com.local.VoiceFlick"
MIN_SYSTEM_VERSION="14.0"
LOCAL_SIGNING_IDENTITY="VoiceFlick Local Code Signing"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

cd "$ROOT_DIR"

if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
  /usr/bin/osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
  sleep 1
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
fi

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  --launch-only|launch-only)
    if [[ ! -d "$APP_BUNDLE" ]]; then
      echo "$APP_BUNDLE does not exist; run $0 first" >&2
      exit 1
    fi
    open_app
    exit 0
    ;;
  --verify-existing|verify-existing)
    if [[ ! -d "$APP_BUNDLE" ]]; then
      echo "$APP_BUNDLE does not exist; run $0 first" >&2
      exit 1
    fi
    open_app
    sleep 5
    pgrep -x "$APP_NAME" >/dev/null
    exit 0
    ;;
esac

swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSCameraUsageDescription</key>
  <string>VoiceFlick uses the camera to recognize hand gestures locally.</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>VoiceFlick uses microphone level only to detect silence while dictation is active. Audio is not recorded or saved.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

find_signing_identity() {
  /usr/bin/security find-identity -v -p codesigning 2>/dev/null \
    | /usr/bin/awk -F\" '/Developer ID Application:|Apple Development:|Mac Developer:/ { print $2; exit }'
}

sign_app() {
  local identity="${1:-}"
  if [[ -n "$identity" ]] \
    && /usr/bin/codesign --force --sign "$identity" "$APP_BUNDLE" >/dev/null 2>&1 \
    && /usr/bin/codesign --verify --deep --strict "$APP_BUNDLE" >/dev/null 2>&1; then
    echo "Signed with trusted identity: $identity"
    return 0
  fi

  if /usr/bin/codesign --force --sign "$LOCAL_SIGNING_IDENTITY" "$APP_BUNDLE" >/dev/null 2>&1 \
    && /usr/bin/codesign --verify --deep --strict "$APP_BUNDLE" >/dev/null 2>&1; then
    echo "Signed with trusted local identity: $LOCAL_SIGNING_IDENTITY"
    return 0
  fi

  /usr/bin/codesign --force --sign - "$APP_BUNDLE" >/dev/null
  echo "Signed ad-hoc because no trusted signing identity was available"
}

sign_app "$(find_signing_identity)"

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 5
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--launch-only|--debug|--logs|--telemetry|--verify|--verify-existing]" >&2
    exit 2
    ;;
esac
