#!/bin/bash
# BrowserRouter Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/phpgao/BrowserRouter/main/install.sh | bash

set -e

APP_NAME="BrowserRouter"
APP_PATH="/Applications/${APP_NAME}.app"
ZIP_NAME="${APP_NAME}.zip"

echo "🌐 Installing ${APP_NAME}..."

# Check if already running, ask to quit
if pgrep -x "$APP_NAME" > /dev/null 2>&1; then
    echo "⚠️  ${APP_NAME} is running. Quitting..."
    osascript -e "tell application \"${APP_NAME}\" to quit" 2>/dev/null || true
    sleep 1
fi

# If a download URL is provided as argument, use it; otherwise look for local zip
if [ -n "$1" ]; then
    echo "📥 Downloading ${APP_NAME}..."
    curl -fSL "$1" -o "/tmp/${ZIP_NAME}"
    echo "📦 Extracting..."
    ditto -xk "/tmp/${ZIP_NAME}" /Applications/
    rm -f "/tmp/${ZIP_NAME}"
elif [ -f "${ZIP_NAME}" ]; then
    echo "📦 Extracting from local ${ZIP_NAME}..."
    ditto -xk "${ZIP_NAME}" /Applications/
else
    echo "❌ No download URL or local ${ZIP_NAME} found."
    echo "Usage: ./install.sh [download_url]"
    exit 1
fi

# Remove quarantine attribute to bypass Gatekeeper
echo "🔓 Removing quarantine attribute..."
xattr -cr "${APP_PATH}" 2>/dev/null || true

echo "✅ ${APP_NAME} installed to ${APP_PATH}"
echo ""
echo "🚀 Launching ${APP_NAME}..."
open "${APP_PATH}"
echo ""
echo "💡 To set as default browser: Open Preferences → System → Set as Default"
