#!/usr/bin/env bash
set -euo pipefail

exec > >(tee -a codemagic_build_ipa.log) 2>&1

echo "== Build IPA =="

xcode-project use-profiles --project ios/Runner.xcodeproj
xcode-project build-ipa --project ios/Runner.xcodeproj --scheme Runner

