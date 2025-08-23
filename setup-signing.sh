#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LOG_FILE="$ROOT_DIR/codemagic_setup_signing.log"
: > "$LOG_FILE"; exec > >(tee -a "$LOG_FILE") 2>&1

echo "== Setup signing (auto) =="

need(){ [ -n "${!1:-}" ] || { echo "ERROR: falta $1"; exit 2; }; }
need APP_STORE_CONNECT_ISSUER_ID
need APP_STORE_CONNECT_KEY_IDENTIFIER
need APP_STORE_CONNECT_PRIVATE_KEY     # .p8 (ASC)
need APPLE_CERTIFICATE_PRIVATE_KEY     # RSA 2048 PEM sin passphrase
need APPLE_TEAM_ID
need BUNDLE_ID

# Keychain de Codemagic
keychain initialize
KEYCHAIN_PATH="$(keychain get-default | awk 'END{print $NF}')"
echo "Default keychain: $KEYCHAIN_PATH"

# Guardar API key en fichero para evitar problemas de formato
ASC_KEY=/tmp/asc_api_key.p8
printf '%s\n' "$APP_STORE_CONNECT_PRIVATE_KEY" > "$ASC_KEY"

# (Opcional) instalar un perfil aportado por env
if [[ -n "${IOS_APPSTORE_PROFILE_B64:-}" ]]; then
  echo "Instalando perfil desde IOS_APPSTORE_PROFILE_B64..."
  INSTALL_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
  mkdir -p "$INSTALL_DIR"
  TMP_DIR="$(mktemp -d)"
  echo "$IOS_APPSTORE_PROFILE_B64" | base64 --decode > "$TMP_DIR/profile.mobileprovision"
  cp -f "$TMP_DIR/profile.mobileprovision" "$INSTALL_DIR/appstore.mobileprovision"
fi

# Determinar flag de clave privada para fetch
CERT_FLAG="--certificate-key"
app-store-connect fetch-signing-files --help | grep -q -- "--certificate-key" || CERT_FLAG="--cert-private-key"

# Traer/crear cert + perfil App Store
app-store-connect fetch-signing-files "$BUNDLE_ID" \
  --type IOS_APP_STORE \
  --issuer-id "$APP_STORE_CONNECT_ISSUER_ID" \
  --key-id "$APP_STORE_CONNECT_KEY_IDENTIFIER" \
  --private-key "$ASC_KEY" \
  $CERT_FLAG "$APPLE_CERTIFICATE_PRIVATE_KEY" \
  --create

# Importar certs y aplicar perfiles
keychain add-certificates || true
xcode-project use-profiles

echo "Identidades de firma:"
security find-identity -v -p codesigning "$KEYCHAIN_PATH" || true

echo "Perfiles disponibles:"
ls -la ~/Library/MobileDevice/Provisioning\ Profiles/ || true

mkdir -p artifacts
cp "$LOG_FILE" artifacts/ || true
echo "Setup signing DONE"
