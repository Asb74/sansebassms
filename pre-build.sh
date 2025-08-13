#!/usr/bin/env bash
set -e

echo "Flutter: $(flutter --version)"
echo "Ruby: $(ruby -v)"
echo "CocoaPods: $(pod --version)"
xcodebuild -version

# 1) Flutter deps
flutter pub get
flutter precache --ios

# 2) Ensure Runner project targets iOS 15.0 minimum
/usr/bin/sed -i '' -E \
  "s/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+/IPHONEOS_DEPLOYMENT_TARGET = 15.0/g" \
  ios/Runner.xcodeproj/project.pbxproj

# 3) Clean and install Pods
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
# Quick verification of pod and xcconfig resolution
grep -E "Pods-Runner\.(debug|release|profile)\.xcconfig" Flutter/*.xcconfig || true
grep -E "BoringSSL|gRPC|Firebase|abseil" Podfile.lock || true
cd ..

# 4) Automatic distribution signing
# Check required App Store Connect variables are present
: "${APP_STORE_CONNECT_ISSUER_ID:?Missing APP_STORE_CONNECT_ISSUER_ID}"
: "${APP_STORE_CONNECT_KEY_IDENTIFIER:?Missing APP_STORE_CONNECT_KEY_IDENTIFIER}"
: "${APP_STORE_CONNECT_PRIVATE_KEY:?Missing APP_STORE_CONNECT_PRIVATE_KEY}"
echo "Using App Store Connect issuer: $APP_STORE_CONNECT_ISSUER_ID"
app-store-connect fetch-signing-files "$BUNDLE_ID" --type IOS_APP_STORE --create
keychain initialize
keychain add-certificates
xcode-project use-profiles

# 5) Signing diagnostics
security find-identity -v -p codesigning || true
ls -la ~/Library/MobileDevice/Provisioning\ Profiles/ || true

# 6) Collect useful artifacts
mkdir -p artifacts
cp ios/Podfile.lock artifacts/ || true
