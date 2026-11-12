#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/app"
RES_DIR="$APP_DIR/Resources"
DIST_DIR="$ROOT/dist"
STAGE_DIR="/tmp/xampplocal_dmg_stage"
BG_PNG="/tmp/xampplocal_dmg_bg.png"
DMG_NAME="XamppLocal.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"

echo "==> Rebuilding XamppControl.app"
"$APP_DIR/build.sh"

echo "==> Generating Retina DMG background"
swift -module-cache-path /tmp/swift_modcache "$RES_DIR/generate_dmg_bg.swift" "$BG_PNG"

rm -rf "$STAGE_DIR" "$DIST_DIR"/*.dmg "$DIST_DIR"/*.sha256
mkdir -p "$STAGE_DIR" "$DIST_DIR"

ditto "$APP_DIR/XamppControl.app" "$STAGE_DIR/XamppControl.app"

echo "==> Packaging $DMG_PATH with create-dmg"
create-dmg \
  --volname "XamppLocal" \
  --volicon "$RES_DIR/AppIcon.icns" \
  --background "$BG_PNG" \
  --window-pos 240 160 \
  --window-size 540 320 \
  --icon-size 104 \
  --text-size 13 \
  --icon "XamppControl.app" 145 155 \
  --hide-extension "XamppControl.app" \
  --app-drop-link 395 155 \
  --no-internet-enable \
  "$DMG_PATH" \
  "$STAGE_DIR"

rm -rf "$STAGE_DIR" "$BG_PNG"
(cd "$DIST_DIR" && shasum -a 256 "$DMG_NAME" > "${DMG_NAME}.sha256")
ls -lh "$DMG_PATH" "${DMG_PATH}.sha256"
cat "${DMG_PATH}.sha256"
