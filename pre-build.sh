#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LOG_FILE="$ROOT_DIR/codemagic_prebuild.log"
: > "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

require_env() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "ERROR: Missing required env var: $name"
    echo "Sugerencia: define $name en Codemagic → App settings → Environment variables (grupo app_store_connect)."
    return 1
  fi
}

if ! require_env APP_STORE_CONNECT_ISSUER_ID \
     || ! require_env APP_STORE_CONNECT_KEY_IDENTIFIER \
     || ! require_env APP_STORE_CONNECT_PRIVATE_KEY \
     || ! require_env BUNDLE_ID; then
  echo "Pre-build abortado por credenciales incompletas."
  mkdir -p artifacts
  cp "$LOG_FILE" artifacts/ || true
  exit 2
fi

echo "Flutter: $(flutter --version)"; echo "Ruby: $(ruby -v)"; echo "CocoaPods: $(pod --version)"; xcodebuild -version

flutter pub get
flutter precache --ios

/usr/bin/sed -i '' -E "s/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+/IPHONEOS_DEPLOYMENT_TARGET = 15.0/g" ios/Runner.xcodeproj/project.pbxproj

cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
cd ..

app-store-connect fetch-signing-files "$BUNDLE_ID" --type IOS_APP_STORE --create
keychain initialize
keychain add-certificates
xcode-project use-profiles

security find-identity -v -p codesigning || true
ls -la ~/Library/MobileDevice/Provisioning\ Profiles/ || true
mkdir -p artifacts
grep -E "BoringSSL|gRPC|Firebase|abseil" ios/Podfile.lock | tee artifacts/pods-versions.txt || true
cp ios/Podfile.lock artifacts/ || true
cp "$LOG_FILE" artifacts/ || true
