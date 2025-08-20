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

# Extract provisioning profile and entitlements
TMP_DIR=$(mktemp -d)
unzip -q "$IPA_PATH" -d "$TMP_DIR"
APP_DIR=$(find "$TMP_DIR/Payload" -maxdepth 1 -name "*.app" -print -quit)
if [ -z "$APP_DIR" ]; then
  echo "❌ .app bundle not found inside IPA"
  exit 1
fi

# Save embedded.mobileprovision for inspection
cp "$APP_DIR/embedded.mobileprovision" "$ROOT_DIR/embedded.mobileprovision"

# Extract entitlements from the app
ENTITLEMENTS_PLIST="$ROOT_DIR/app.entitlements.plist"
codesign -d --entitlements :- "$APP_DIR" > "$ENTITLEMENTS_PLIST" 2>/dev/null
plutil -convert xml1 -o "$ENTITLEMENTS_PLIST" "$ENTITLEMENTS_PLIST"

# Check for push notification capabilities
if grep -q "<key>aps-environment</key>" "$ENTITLEMENTS_PLIST"; then
  echo "✅ aps-environment capability present"
else
  echo "❌ aps-environment capability missing"
  exit 1
fi

if grep -q "<key>com.apple.developer.usernotifications</key>" "$ENTITLEMENTS_PLIST"; then
  echo "✅ com.apple.developer.usernotifications capability present"
else
  echo "❌ com.apple.developer.usernotifications capability missing"
  exit 1
fi

rm -rf "$TMP_DIR"
rm -f ipa_contents.log

mkdir -p artifacts
cp "$LOG_FILE" artifacts/ || true
echo "Build IPA DONE"
