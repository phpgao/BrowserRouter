#!/bin/bash
# Build and package BrowserRouter for distribution
set -euo pipefail

SCHEME="BrowserRouter"
DERIVED_DATA="$(mktemp -d)"
OUTPUT_DIR="$(pwd)/dist"

echo "🔨 Building ${SCHEME} (Release)..."
xcodebuild -scheme "$SCHEME" -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    build 2>&1 | tail -5

# Check build result
if [ ${PIPESTATUS[0]} -ne 0 ] 2>/dev/null; then
    echo "❌ Build failed"
    rm -rf "$DERIVED_DATA"
    exit 1
fi

APP_PATH="${DERIVED_DATA}/Build/Products/Release/${SCHEME}.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Build failed — ${APP_PATH} not found"
    rm -rf "$DERIVED_DATA"
    exit 1
fi

# Remove quarantine and extended attributes
echo "🔓 Removing extended attributes..."
xattr -cr "$APP_PATH"

# Get version before cleanup
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${APP_PATH}/Contents/Info.plist" 2>/dev/null || echo "unknown")

echo "📦 Packaging..."
mkdir -p "$OUTPUT_DIR"
ZIP_PATH="${OUTPUT_DIR}/${SCHEME}.zip"
ditto -ck --keepParent "$APP_PATH" "$ZIP_PATH"

# Cleanup
rm -rf "$DERIVED_DATA"

SIZE=$(du -h "$ZIP_PATH" | cut -f1)
echo ""
echo "✅ Done!"
echo "   Version: ${VERSION}"
echo "   Output:  ${ZIP_PATH}"
echo "   Size:    ${SIZE}"
echo ""
echo "📤 Upload to GitHub Releases or distribute directly."
echo "   Users can install with:"
echo "   ./install.sh or manually: unzip → drag to /Applications → xattr -cr /Applications/${SCHEME}.app"
