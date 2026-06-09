#!/bin/bash
#
# Updates VideoSlicer to the latest GitHub release.
# Run it again any time to get the newest version. Works on Intel and
# Apple Silicon (the release is a universal binary).
#
# One-time setup per Mac:
#   brew install gh
#   gh auth login        # pick GitHub.com -> SSH or HTTPS, your account
#
# Then just run:  ./update.sh
#
set -euo pipefail

REPO="roman-algo/VideoSlicer"
APP="/Applications/VideoSlicer.app"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading latest release of $REPO ..."
gh release download --repo "$REPO" --pattern "VideoSlicer.zip" --dir "$TMP" --clobber

echo "Installing ..."
ditto -x -k "$TMP/VideoSlicer.zip" "$TMP"
rm -rf "$APP"
mv "$TMP/VideoSlicer.app" "$APP"
xattr -dr com.apple.quarantine "$APP"

VER="$(gh release view --repo "$REPO" --json tagName -q .tagName)"
echo "Updated VideoSlicer to $VER."
open "$APP"
