#!/bin/bash
# Builds Kumone with SwiftPM and wraps the product into a .app bundle.
# Usage: Scripts/build-app.sh [debug|release]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

CONF="${1:-debug}"
APP_NAME="VibeaseMusic"
# Overridable so side-by-side preview builds don't collide with the real app.
BUNDLE_ID="${BUNDLE_ID:-com.vibease.music}"
APP_DISPLAY_NAME="${APP_DISPLAY_NAME:-$APP_NAME}"
# Version resolution: environment > version.env > defaults.
ENV_MARKETING_VERSION="${MARKETING_VERSION:-}"
ENV_BUILD_NUMBER="${BUILD_NUMBER:-}"
MARKETING_VERSION="0.1.0"
BUILD_NUMBER="1"
[ -f "$ROOT/version.env" ] && source "$ROOT/version.env"
[ -n "$ENV_MARKETING_VERSION" ] && MARKETING_VERSION="$ENV_MARKETING_VERSION"
[ -n "$ENV_BUILD_NUMBER" ] && BUILD_NUMBER="$ENV_BUILD_NUMBER"

SPARKLE_FEED_URL="https://github.com/aveyron1799-tech/VibeaseMusic/releases/latest/download/appcast.xml"
SPARKLE_PUBLIC_ED_KEY="RHEhllstUuuVrVDCPGrbhg/8LivSzpuZB9X3u3xdV5o="

BUILD_DIR="$ROOT/.build/app"
APP_BUNDLE="$BUILD_DIR/$APP_DISPLAY_NAME.app"

# Link against the active SDK so AppKit enables the matching system appearance.
SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
swift build -c "$CONF" --product "$APP_NAME" \
  -Xlinker -platform_version -Xlinker macos -Xlinker 15.0 -Xlinker "$SDK_VERSION"
BIN_PATH="$(swift build -c "$CONF" --show-bin-path)"

rm -rf "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Embed Sparkle.framework (SwiftPM binary artifact) into Contents/Frameworks.
SPARKLE_FW="$(find "$ROOT/.build/artifacts" -type d -name 'Sparkle.framework' -path '*macos*' 2>/dev/null | head -n1)"
if [ -z "$SPARKLE_FW" ]; then
  echo "ERROR: Sparkle.framework not found under .build/artifacts" >&2
  exit 1
fi
mkdir -p "$APP_BUNDLE/Contents/Frameworks"
cp -a "$SPARKLE_FW" "$APP_BUNDLE/Contents/Frameworks/"

# Localization tables → Bundle.main
for lproj in "$ROOT"/Sources/VibeaseMusic/Resources/*.lproj; do
  [ -d "$lproj" ] && cp -R "$lproj" "$APP_BUNDLE/Contents/Resources/"
done

# SwiftPM resource bundles (if any)
find "$BIN_PATH" -maxdepth 1 -name '*.bundle' -not -name '*Tests*' -print0 |
  while IFS= read -r -d '' bundle; do
    cp -R "$bundle" "$APP_BUNDLE/Contents/Resources/"
  done

# App icon: install standard multi-resolution AppIcon.icns
if [ -f "$ROOT/AppIcon.icns" ]; then
  cp "$ROOT/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/VibeaseMusicIcon.icns"
fi

printf 'APPL????' > "$APP_BUNDLE/Contents/PkgInfo"

GIT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>zh-Hans</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>zh-Hans</string>
        <string>en</string>
    </array>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>VibeaseMusicIcon</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>$APP_DISPLAY_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_DISPLAY_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$MARKETING_VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.music</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>NSHumanReadableCopyright</key><string>© 2026 VibeaseMusic</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key><true/>
    </dict>
    <key>VibeaseMusicGitCommit</key><string>$GIT_COMMIT</string>
    <key>SUEnableAutomaticChecks</key><false/>
</dict>
</plist>
PLIST

xattr -cr "$APP_BUNDLE" 2>/dev/null || true
codesign --force --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true

echo "Built $APP_BUNDLE ($CONF, $GIT_COMMIT)"
