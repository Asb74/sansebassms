#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LOG_FILE="$ROOT_DIR/prebuild.log"
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

has_api=true
for var in APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_KEY_IDENTIFIER APP_STORE_CONNECT_PRIVATE_KEY; do
  if [ -z "${!var:-}" ]; then
    has_api=false
    break
  fi
done

has_p12=true
for var in CERTIFICATE_P12_BASE64 P12_PASSWORD; do
  if [ -z "${!var:-}" ]; then
    has_p12=false
    break
  fi
done

if [ "$missing" = true ]; then
  echo "Pre-build aborted due to missing mandatory environment variables." >&2
  exit 2
fi

if [ "$has_api" = false ] && [ "$has_p12" = false ]; then
  echo "ERROR: Provide App Store Connect API credentials or CERTIFICATE_P12_BASE64 and P12_PASSWORD." >&2
  exit 2
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
