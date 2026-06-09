#!/bin/bash
#
# Updates VideoSlicer to the latest GitHub release.
# Run it again any time to get the newest version. Works on Intel and
# Apple Silicon (the release is a universal binary). No login required.
#
# Usage:  ./update.sh
#
set -euo pipefail

URL="https://github.com/roman-algo/VideoSlicer/releases/latest/download/VideoSlicer.zip"
APP="/Applications/VideoSlicer.app"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading the latest release ..."
curl -fsSL "$URL" -o "$TMP/VideoSlicer.zip"

echo "Installing ..."
ditto -x -k "$TMP/VideoSlicer.zip" "$TMP"
rm -rf "$APP"
mv "$TMP/VideoSlicer.app" "$APP"
xattr -dr com.apple.quarantine "$APP"

echo "Updated. Launching VideoSlicer."
open "$APP"
