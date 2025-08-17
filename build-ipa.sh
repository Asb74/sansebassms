#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LOG_FILE="$ROOT_DIR/codemagic_build_ipa.log"
: > "$LOG_FILE"; exec > >(tee -a "$LOG_FILE") 2>&1

echo "== Build IPA =="
# Ensure dependencies and iOS workspace are prepared
"$ROOT_DIR/pre-build.sh"
xcode-project use-profiles
flutter build ipa --release --export-options-plist /Users/builder/export_options.plist

mkdir -p artifacts
cp build/ios/ipa/*.ipa artifacts/ || true
cp "$LOG_FILE" artifacts/ || true
echo "Build IPA DONE"
