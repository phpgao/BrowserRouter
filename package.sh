#!/bin/bash
# Build and package BrowserRouter for distribution
set -eo pipefail

SCHEME="BrowserRouter"
DERIVED_DATA="$(mktemp -d)"
OUTPUT_DIR="$(pwd)/dist"

# Calculate build number: total commit count (monotonically increasing)
BUILD_NUMBER=$(git rev-list --count HEAD)
echo "🔢 Build number: ${BUILD_NUMBER}"

echo "🔨 Building ${SCHEME} (Release)..."
xcodebuild -scheme "$SCHEME" -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    build 2>&1 | tail -5

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

# Cleanup build artifacts
rm -rf "$DERIVED_DATA"

SIZE=$(du -h "$ZIP_PATH" | cut -f1)

# Sign update with Sparkle's sign_update tool (if available)
SPARKLE_SIGN="$(find "${HOME}/Library/Developer/Xcode/DerivedData" -path '*/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update' -print -quit 2>/dev/null || true)"
if [ -n "$SPARKLE_SIGN" ] && [ -x "$SPARKLE_SIGN" ]; then
    echo "🔏 Signing update with Sparkle..."
    SIGNATURE=$("$SPARKLE_SIGN" "$ZIP_PATH" 2>&1) || true
    echo "   Signature: ${SIGNATURE}"
else
    echo "⚠️  Sparkle sign_update not found — skipping EdDSA signing"
    echo "   Build once in Xcode to fetch Sparkle artifacts, then re-run."
fi

# Generate SHA256 checksum
SHA256=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')
echo "${SHA256}  ${SCHEME}.zip" > "${OUTPUT_DIR}/SHA256.txt"

echo ""
echo "✅ Done!"
echo "   Version: ${VERSION} (${BUILD_NUMBER})"
echo "   Output:  ${ZIP_PATH}"
echo "   Size:    ${SIZE}"
echo "   SHA256:  ${SHA256}"
echo ""
echo "📤 Upload to GitHub Releases or distribute directly."
echo "   Users can install with:"
echo "   ./install.sh or manually: unzip → drag to /Applications → xattr -cr /Applications/${SCHEME}.app"
