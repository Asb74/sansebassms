#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LOG_FILE="$ROOT_DIR/codemagic_setup_signing.log"
: > "$LOG_FILE"; exec > >(tee -a "$LOG_FILE") 2>&1

echo "== Setup signing (auto) =="

need(){ [ -n "${!1:-}" ] || { echo "ERROR: falta $1"; exit 2; }; }
need APP_STORE_CONNECT_ISSUER_ID
need APP_STORE_CONNECT_KEY_IDENTIFIER
need APP_STORE_CONNECT_PRIVATE_KEY     # .p8 (EC)
need APPLE_CERTIFICATE_PRIVATE_KEY     # RSA 2048 PEM sin passphrase
need APPLE_TEAM_ID
need BUNDLE_ID

# No usar P12 manual en este flujo
unset CERTIFICATE_P12_BASE64 P12_PASSWORD || true

# Llavero por defecto de Codemagic
keychain initialize
KEYCHAIN_PATH="$(keychain get-default | awk 'END{print $NF}')"
echo "Default keychain: $KEYCHAIN_PATH"

# Descarga/creación de cert + perfiles (usa la RSA como certificado-key)
CERT_FLAG="--certificate-key"
app-store-connect fetch-signing-files --help | grep -q -- "--certificate-key" || CERT_FLAG="--cert-private-key"

app-store-connect fetch-signing-files "$BUNDLE_ID" \
  --type IOS_APP_STORE \
  --issuer-id "$APP_STORE_CONNECT_ISSUER_ID" \
  --key-id "$APP_STORE_CONNECT_KEY_IDENTIFIER" \
  --private-key "$APP_STORE_CONNECT_PRIVATE_KEY" \
  $CERT_FLAG "$APPLE_CERTIFICATE_PRIVATE_KEY" \
  --create

# Importar lo descargado al keychain por defecto
keychain add-certificates || true

echo "Identidades de firma:"
security find-identity -v -p codesigning "$KEYCHAIN_PATH" || true

echo "Perfiles disponibles:"
ls -la ~/Library/MobileDevice/Provisioning\ Profiles/ || true

mkdir -p artifacts
cp "$LOG_FILE" artifacts/ || true
echo "Setup signing DONE"
