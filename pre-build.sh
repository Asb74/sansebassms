#!/bin/bash
set -euo pipefail

echo "===== PRE BUILD SCRIPT STARTED ====="

# Ensure dependencies are up to date
flutter clean
flutter pub get

# Prepare CocoaPods dependencies
cd ios
pod install --repo-update
cd ..

echo "===== PRE BUILD SCRIPT FINISHED ====="
