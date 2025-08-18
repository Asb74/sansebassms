#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LOG_FILE="$ROOT_DIR/codemagic_build_ipa.log"
: > "$LOG_FILE"; exec > >(tee -a "$LOG_FILE") 2>&1

echo "== Build IPA =="

# Recreate GoogleService-Info.plist from environment variable
if [ -z "${GOOGLE_SERVICE_INFO_PLIST_B64:-}" ]; then
  echo "ERROR: GOOGLE_SERVICE_INFO_PLIST_B64 is not set"
  exit 1
fi
PLIST_PATH="ios/Runner/GoogleService-Info.plist"
echo "$GOOGLE_SERVICE_INFO_PLIST_B64" | base64 --decode > "$PLIST_PATH"
echo "Wrote $PLIST_PATH ($(wc -c < "$PLIST_PATH") bytes)"

xcode-project use-profiles
flutter build ipa --release --export-options-plist /Users/builder/export_options.plist

# Verify that the plist is included inside the generated .ipa
IPA_PATH=$(find build/ios/ipa -name "*.ipa" -print -quit)
if [ -z "$IPA_PATH" ]; then
  echo "❌ IPA file not found"
  exit 1
fi

echo "Listing contents of $IPA_PATH"
unzip -l "$IPA_PATH" | tee ipa_contents.log
if grep -q "GoogleService-Info.plist" ipa_contents.log; then
  echo "✅ GoogleService-Info.plist found in IPA"
else
  echo "❌ GoogleService-Info.plist missing from IPA"
  exit 1
fi
rm -f ipa_contents.log

mkdir -p artifacts
cp "$LOG_FILE" artifacts/ || true
echo "Build IPA DONE"
