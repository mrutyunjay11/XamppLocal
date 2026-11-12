#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
RES_DIR="$APP_DIR/Resources"
BUNDLE="$APP_DIR/XamppControl.app"
SDK="$(xcrun --show-sdk-path)"

if [ ! -f "$RES_DIR/AppIcon.icns" ] || [ ! -f "$RES_DIR/logo.png" ]; then
  swift -module-cache-path /tmp/swift_modcache "$RES_DIR/generate_icon.swift" "$RES_DIR"
  /usr/bin/iconutil -c icns "$RES_DIR/AppIcon.iconset" -o "$RES_DIR/AppIcon.icns"
  rm -rf "$RES_DIR/AppIcon.iconset" "$RES_DIR/AppIcon-1024.png"
fi

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources/stack/bin" "$BUNDLE/Contents/Resources/stack/scripts"
cp "$RES_DIR/Info.plist" "$BUNDLE/Contents/Info.plist"
cp "$RES_DIR/AppIcon.icns" "$BUNDLE/Contents/Resources/AppIcon.icns"
cp "$RES_DIR/logo.png" "$BUNDLE/Contents/Resources/logo.png"

ROOT_DIR="$(cd "$APP_DIR/.." && pwd)"
cp "$ROOT_DIR/bin/xamppctl" "$BUNDLE/Contents/Resources/stack/bin/xamppctl"
chmod +x "$BUNDLE/Contents/Resources/stack/bin/xamppctl"
cp -R "$ROOT_DIR/config" "$BUNDLE/Contents/Resources/stack/config"
rm -f "$BUNDLE/Contents/Resources/stack/config/httpd/vhosts.d/"*.conf 2>/dev/null || true
cp -R "$ROOT_DIR/htdocs-template" "$BUNDLE/Contents/Resources/stack/htdocs-template"
cp "$ROOT_DIR/scripts/setup.sh" "$BUNDLE/Contents/Resources/stack/scripts/setup.sh"
chmod +x "$BUNDLE/Contents/Resources/stack/scripts/setup.sh"

swiftc -O -whole-module-optimization \
  -module-cache-path /tmp/swift_modcache \
  -target arm64-apple-macosx14.0 \
  -sdk "$SDK" \
  -framework AppKit \
  "$APP_DIR"/Sources/*.swift \
  -o "$BUNDLE/Contents/MacOS/XamppControl"

codesign --force --deep --sign - "$BUNDLE"
touch "$BUNDLE"
LSREG="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
if [ -x "$LSREG" ]; then
  "$LSREG" -f "$BUNDLE" >/dev/null 2>&1 || true
fi

echo "Built $BUNDLE:"
file "$BUNDLE/Contents/MacOS/XamppControl"
