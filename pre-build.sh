#!/usr/bin/env bash
set -e

echo "Flutter: $(flutter --version)"
echo "Ruby: $(ruby -v)"
echo "CocoaPods: $(pod --version)"
xcodebuild -version

# 1) Flutter deps
flutter pub get
flutter precache --ios

# 2) Force iOS 18 in Runner (project file)
/usr/bin/sed -i '' -E "s/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+/IPHONEOS_DEPLOYMENT_TARGET = 18.0/g" ios/Runner.xcodeproj/project.pbxproj

# 3) Clean and install Pods
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
cd ..

# 4) Automatic distribution signing
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
