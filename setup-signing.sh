#!/usr/bin/env bash
set -euo pipefail

exec > >(tee -a codemagic_setup_signing.log) 2>&1

echo "== Setup signing =="

# Validate required environment variables
require() {
  local var="$1"
  if [ -z "${!var:-}" ]; then
    echo "Missing $var" >&2
    exit 2
  fi
}

for v in APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_KEY_IDENTIFIER APP_STORE_CONNECT_PRIVATE_KEY BUNDLE_ID APPLE_TEAM_ID; do
  require "$v"
done

# Initialize ephemeral/default keychain
if [ -n "${KEYCHAIN_PASSWORD:-}" ]; then
  keychain initialize --password "$KEYCHAIN_PASSWORD"
else
  keychain initialize
fi

if [ -n "${CERTIFICATE_P12_BASE64:-}" ] && [ -n "${P12_PASSWORD:-}" ]; then
  echo "Importing provided P12 certificate"
  keychain add-certificates --certificate-base64 "$CERTIFICATE_P12_BASE64" --certificate-password "$P12_PASSWORD"
else
  echo "Fetching signing files from App Store Connect"
  app-store-connect fetch-signing-files \
    --issuer-id @env:APP_STORE_CONNECT_ISSUER_ID \
    --key-id @env:APP_STORE_CONNECT_KEY_IDENTIFIER \
    --private-key @env:APP_STORE_CONNECT_PRIVATE_KEY \
    --team-id @env:APPLE_TEAM_ID \
    @env:BUNDLE_ID
fi

# Show resulting certificates and profiles
ls -la "$HOME/Library/MobileDevice/Certificates" || true
ls -la "$HOME/Library/MobileDevice/Provisioning Profiles" || true

