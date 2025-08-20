#!/usr/bin/env bash
set -euo pipefail
PLIST_RUNNER="ios/Runner/Info.plist"
PLIST_GOOGLE="ios/Runner/GoogleService-Info.plist"

# Verifica que existe el plist de Firebase (lo genera el job)
test -f "$PLIST_GOOGLE"

# Lee REVERSED_CLIENT_ID desde GoogleService-Info.plist
REV=$(/usr/libexec/PlistBuddy -c 'Print :REVERSED_CLIENT_ID' "$PLIST_GOOGLE")
if [[ -n "${REV:-}" ]]; then
  # Asegura CFBundleURLTypes con el URL scheme correcto
  /usr/libexec/PlistBuddy -c "Delete :CFBundleURLTypes" "$PLIST_RUNNER" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes array" "$PLIST_RUNNER"
  /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" "$PLIST_RUNNER"
  /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$PLIST_RUNNER"
  /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string $REV" "$PLIST_RUNNER"
fi

# Asegura Background Modes -> remote-notification en Info.plist (no en entitlements)
if ! /usr/libexec/PlistBuddy -c "Print :UIBackgroundModes" "$PLIST_RUNNER" >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes array" "$PLIST_RUNNER"
fi
if ! /usr/libexec/PlistBuddy -c "Print :UIBackgroundModes" "$PLIST_RUNNER" | grep -q "remote-notification"; then
  /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes:0 string remote-notification" "$PLIST_RUNNER"
fi
echo "Patched Info.plist (URL scheme & UIBackgroundModes)."

