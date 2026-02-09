#!/bin/bash
#
# build_dmg.sh — Build ProseKit.app and package it into a DMG.
#
# Usage:
#   ./scripts/build_dmg.sh                    # Unsigned build
#   ./scripts/build_dmg.sh --sign "Developer ID Application: Your Name (TEAMID)"
#   ./scripts/build_dmg.sh --sign "IDENTITY" --notarize "TEAMID"
#
# Prerequisites:
#   - Xcode 15+ with command line tools
#   - Apple Silicon Mac
#   - For signing: Apple Developer certificate installed in Keychain
#   - For notarization: App-specific password in Keychain (xcrun notarytool)
#
# Output:
#   build/ProseKit-v{VERSION}.dmg

set -euo pipefail

# ─── Configuration ─────────────────────────────────────────────────────────────

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
XCODE_PROJECT="$PROJECT_DIR/ProseKit/ProseKit.xcodeproj"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="ProseKit"
BUNDLE_ID="com.abdurraafay.prosekit"
VERSION="${VERSION:-0.1.0}"

SIGN_IDENTITY=""
NOTARIZE_TEAM=""

# ─── Parse Arguments ───────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case $1 in
        --sign)
            SIGN_IDENTITY="$2"
            shift 2
            ;;
        --notarize)
            NOTARIZE_TEAM="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

DMG_NAME="${APP_NAME}-v${VERSION}.dmg"

echo "=========================================="
echo "  ProseKit DMG Builder"
echo "  Version: $VERSION"
echo "  Sign: ${SIGN_IDENTITY:-unsigned}"
echo "  Notarize: ${NOTARIZE_TEAM:-no}"
echo "=========================================="

# ─── Clean ─────────────────────────────────────────────────────────────────────

echo ""
echo "[1/6] Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ─── Archive ───────────────────────────────────────────────────────────────────

echo "[2/6] Building Release archive..."
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"

xcodebuild archive \
    -project "$XCODE_PROJECT" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=macOS" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="1" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    CODE_SIGN_IDENTITY="${SIGN_IDENTITY:--}" \
    CODE_SIGNING_REQUIRED="${SIGN_IDENTITY:+YES}" \
    CODE_SIGNING_ALLOWED="YES" \
    2>&1 | tail -20

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo "ERROR: Archive failed. Check Xcode build output above."
    exit 1
fi

echo "  Archive created: $ARCHIVE_PATH"

# ─── Export App ────────────────────────────────────────────────────────────────

echo "[3/6] Exporting .app bundle..."
APP_PATH="$BUILD_DIR/$APP_NAME.app"

# Create export options plist
EXPORT_PLIST="$BUILD_DIR/ExportOptions.plist"
cat > "$EXPORT_PLIST" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
PLIST

# If unsigned, just copy from archive directly
if [ -z "$SIGN_IDENTITY" ]; then
    cp -R "$ARCHIVE_PATH/Products/Applications/$APP_NAME.app" "$APP_PATH"
    echo "  Exported (unsigned): $APP_PATH"
else
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportOptionsPlist "$EXPORT_PLIST" \
        -exportPath "$BUILD_DIR/export" \
        2>&1 | tail -10

    cp -R "$BUILD_DIR/export/$APP_NAME.app" "$APP_PATH"
    echo "  Exported (signed): $APP_PATH"
fi

# Verify the app exists
if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: App bundle not found at $APP_PATH"
    exit 1
fi

# ─── Notarize (optional) ──────────────────────────────────────────────────────

if [ -n "$NOTARIZE_TEAM" ] && [ -n "$SIGN_IDENTITY" ]; then
    echo "[4/6] Notarizing..."

    # Create a zip for notarization
    NOTARIZE_ZIP="$BUILD_DIR/$APP_NAME-notarize.zip"
    ditto -c -k --keepParent "$APP_PATH" "$NOTARIZE_ZIP"

    xcrun notarytool submit "$NOTARIZE_ZIP" \
        --team-id "$NOTARIZE_TEAM" \
        --wait \
        2>&1 | tail -10

    # Staple the notarization ticket
    xcrun stapler staple "$APP_PATH"
    echo "  Notarized and stapled."

    rm -f "$NOTARIZE_ZIP"
else
    echo "[4/6] Skipping notarization."
fi

# ─── Create DMG ───────────────────────────────────────────────────────────────

echo "[5/6] Creating DMG..."
DMG_PATH="$BUILD_DIR/$DMG_NAME"
DMG_TEMP="$BUILD_DIR/dmg_temp"

# Create DMG staging directory
mkdir -p "$DMG_TEMP"
cp -R "$APP_PATH" "$DMG_TEMP/"

# Add Applications symlink for drag-to-install
ln -s /Applications "$DMG_TEMP/Applications"

# Create the DMG
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov \
    -format UDZO \
    "$DMG_PATH" \
    2>&1 | tail -5

rm -rf "$DMG_TEMP"

if [ ! -f "$DMG_PATH" ]; then
    echo "ERROR: DMG creation failed."
    exit 1
fi

# ─── Summary ──────────────────────────────────────────────────────────────────

echo "[6/6] Done!"
echo ""
echo "=========================================="
echo "  Output: $DMG_PATH"
echo "  Size:   $(du -h "$DMG_PATH" | cut -f1)"
echo "=========================================="
echo ""

# Print SHA256 for Homebrew Cask
SHA256=$(shasum -a 256 "$DMG_PATH" | cut -d' ' -f1)
echo "SHA256: $SHA256"
echo ""
echo "To install:"
echo "  1. Open $DMG_PATH"
echo "  2. Drag ProseKit to Applications"
echo "  3. Launch ProseKit from Applications"
echo "  4. Grant Accessibility permission when prompted"
echo "  5. Wait for model download (~4.3 GB on first launch)"
echo ""

if [ -z "$SIGN_IDENTITY" ]; then
    echo "NOTE: This build is unsigned. Users will need to:"
    echo "  Right-click → Open (first launch only) to bypass Gatekeeper."
    echo ""
    echo "For signed builds, run:"
    echo "  ./scripts/build_dmg.sh --sign 'Developer ID Application: Your Name (TEAMID)'"
fi
