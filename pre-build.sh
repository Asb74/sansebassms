#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LOG_FILE="$ROOT_DIR/codemagic_prebuild.log"
mkdir -p "$ROOT_DIR"
: >"$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting pre-build script"

missing=false
for var in APPLE_TEAM_ID BUNDLE_ID; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Missing required env var: $var"
    missing=true
  fi
done

if [ "$missing" = true ]; then
  echo "Pre-build aborted due to missing mandatory environment variables." >&2
  exit 2
fi

for var in APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_KEY_IDENTIFIER APP_STORE_CONNECT_PRIVATE_KEY; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: app_store_connect group is missing or incomplete. Missing $var." >&2
    exit 2
  fi
done

PLIST_PATH="ios/Runner/GoogleService-Info.plist"
if [[ -n "${GOOGLE_SERVICE_INFO_PLIST_B64:-}" ]]; then
  echo "Processing GOOGLE_SERVICE_INFO_PLIST_B64..."
  mkdir -p ios/Runner
  if printf '%s' "$GOOGLE_SERVICE_INFO_PLIST_B64" | base64 --decode > "$PLIST_PATH.tmp" 2>/dev/null \
    || printf '%s' "$GOOGLE_SERVICE_INFO_PLIST_B64" | base64 -d > "$PLIST_PATH.tmp" 2>/dev/null; then
    mv "$PLIST_PATH.tmp" "$PLIST_PATH"
    echo "Decoded Base64 plist"
  elif grep -q '<plist' <<<"$GOOGLE_SERVICE_INFO_PLIST_B64"; then
    printf '%s' "$GOOGLE_SERVICE_INFO_PLIST_B64" > "$PLIST_PATH"
    echo "Wrote raw XML plist"
  else
    echo "Invalid GOOGLE_SERVICE_INFO_PLIST_B64; Firebase will be disabled"
    rm -f "$PLIST_PATH.tmp"
  fi
  ls -l "$PLIST_PATH" 2>/dev/null || true
fi

if [[ ! -f "$PLIST_PATH" ]]; then
  echo "⚠️ $PLIST_PATH not found. Running WITHOUT Firebase."
  NEW_DEFINE=$(printf 'NO_FIREBASE=true' | base64)
  if [[ -n "${DART_DEFINES:-}" ]]; then
    export DART_DEFINES="${DART_DEFINES},${NEW_DEFINE}"
  else
    export DART_DEFINES="${NEW_DEFINE}"
  fi
else
  echo "✅ Found $PLIST_PATH (Firebase ON)"
fi

echo "Flutter: $(flutter --version 2>/dev/null || echo 'not installed')"
echo "Ruby: $(ruby -v 2>/dev/null || echo 'not installed')"
echo "CocoaPods: $(pod --version 2>/dev/null || echo 'not installed')"
xcodebuild -version 2>/dev/null || true

flutter pub get
flutter precache --ios

/usr/bin/sed -i '' -E "s/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+/IPHONEOS_DEPLOYMENT_TARGET = 15.0/g" \
  ios/Runner.xcodeproj/project.pbxproj

pushd ios >/dev/null
pod install --repo-update
popd >/dev/null

echo "Pre-build script completed"
