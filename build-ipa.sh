#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LOG_FILE="$ROOT_DIR/codemagic_build_ipa.log"
: > "$LOG_FILE"; exec > >(tee -a "$LOG_FILE") 2>&1

echo "== Build IPA =="

# Validación defensiva (el plist ya se recrea en un paso previo)
if [ -z "${GOOGLE_SERVICE_INFO_PLIST_B64:-}" ]; then
  echo "ERROR: GOOGLE_SERVICE_INFO_PLIST_B64 is not set"; exit 1
fi

xcode-project use-profiles
# Build number único por job
flutter build ipa --release \
  --build-number=${BUILD_NUMBER} \
  --export-options-plist /Users/builder/export_options.plist

IPA_PATH=$(find build/ios/ipa -name "*.ipa" -print -quit)
[ -n "$IPA_PATH" ] || { echo "❌ IPA file not found"; exit 1; }

echo "Listing contents of $IPA_PATH"
unzip -l "$IPA_PATH" | tee ipa_contents.log
grep -q "GoogleService-Info.plist" ipa_contents.log && echo "✅ GoogleService-Info.plist found in IPA" || { echo "❌ GoogleService-Info.plist missing from IPA"; exit 1; }

# Inspección de entitlements
TMP_DIR=$(mktemp -d)
unzip -q "$IPA_PATH" -d "$TMP_DIR"
APP_DIR=$(find "$TMP_DIR/Payload" -maxdepth 1 -name "*.app" -print -quit)
[ -n "$APP_DIR" ] || { echo "❌ .app bundle not found inside IPA"; exit 1; }

cp "$APP_DIR/embedded.mobileprovision" "$ROOT_DIR/embedded.mobileprovision"

ENTITLEMENTS_PLIST="$ROOT_DIR/app.entitlements.plist"
codesign -d --entitlements :- "$APP_DIR" > "$ENTITLEMENTS_PLIST" 2>/dev/null || true
plutil -convert xml1 -o "$ENTITLEMENTS_PLIST" "$ENTITLEMENTS_PLIST" || true

# Push obligatorio
if grep -q "<key>aps-environment</key>" "$ENTITLEMENTS_PLIST"; then
  echo "✅ aps-environment capability present"
else
  echo "❌ aps-environment capability missing"; exit 1
fi

# (Se elimina el check de 'com.apple.developer.usernotifications' porque no es requisito para push normales)

rm -rf "$TMP_DIR" ipa_contents.log
mkdir -p artifacts
cp "$LOG_FILE" artifacts/ || true
echo "Build IPA DONE"
