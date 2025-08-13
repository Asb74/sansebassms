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

for v in APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_KEY_IDENTIFIER APP_STORE_CONNECT_PRIVATE_KEY BUNDLE_ID TEAM_ID; do
  require "$v"
done

# APPLE_CERTIFICATE_PRIVATE_KEY required unless using manual P12
if [ -z "${CERTIFICATE_PATH:-}" ]; then
  require APPLE_CERTIFICATE_PRIVATE_KEY
fi

# Initialize ephemeral/default keychain
keychain initialize

if [ -n "${CERTIFICATE_PATH:-}" ] && [ -n "${CERTIFICATE_PASSWORD:-}" ]; then
  echo "Importing provided P12 certificate"
  keychain add-certificates --certificate "$CERTIFICATE_PATH" --certificate-password @env:CERTIFICATE_PASSWORD
else
  echo "Fetching signing files from App Store Connect"
  if app-store-connect fetch-signing-files --help 2>&1 | grep -q -- '--create'; then
    app-store-connect fetch-signing-files \
      --issuer-id @env:APP_STORE_CONNECT_ISSUER_ID \
      --key-id @env:APP_STORE_CONNECT_KEY_IDENTIFIER \
      --private-key @env:APP_STORE_CONNECT_PRIVATE_KEY \
      --certificate-key @env:APPLE_CERTIFICATE_PRIVATE_KEY \
      @env:BUNDLE_ID \
      --create
  else
    app-store-connect fetch-signing-files \
      --issuer-id @env:APP_STORE_CONNECT_ISSUER_ID \
      --key-id @env:APP_STORE_CONNECT_KEY_IDENTIFIER \
      --private-key @env:APP_STORE_CONNECT_PRIVATE_KEY \
      --certificate-key @env:APPLE_CERTIFICATE_PRIVATE_KEY \
      @env:BUNDLE_ID
  fi
fi

# Show resulting certificates and profiles
ls -la "$HOME/Library/MobileDevice/Certificates" || true
ls -la "$HOME/Library/MobileDevice/Provisioning Profiles" || true

