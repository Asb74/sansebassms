#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LOG_FILE="$ROOT_DIR/codemagic_setup_signing.log"
: > "$LOG_FILE"; exec > >(tee -a "$LOG_FILE") 2>&1

echo "== Setup signing =="

# Vars mínimas
require(){ local n="$1"; [ -n "${!n:-}" ] || { echo "ERROR: falta $n"; exit 2; }; }
require APPLE_TEAM_ID
require BUNDLE_ID

# Inicializar llavero efímero (usar CLI oficial de Codemagic)
keychain initialize
KEYCHAIN_PATH="$(keychain get-default | tail -n1 | awk '{print $NF}')"
echo "Default keychain: $KEYCHAIN_PATH"

# 1) Ruta MANUAL: si el usuario aporta un P12 en base64, importarlo con 'security import'
if [ -n "${CERTIFICATE_P12_BASE64:-}" ]; then
  echo "Importando P12 aportado…"
  echo "$CERTIFICATE_P12_BASE64" | base64 --decode > dist.p12
  : "${P12_PASSWORD:?Missing P12_PASSWORD}"
  security import dist.p12 -k "$KEYCHAIN_PATH" -P "$P12_PASSWORD" -T /usr/bin/codesign
fi

# 2) Si aún no hay identidades, usar fetch-signing-files (auto)
HAS_IDS="$(security find-identity -v -p codesigning "$KEYCHAIN_PATH" | grep -cE 'Apple (Distribution|Development)' || true)"
if [ "${HAS_IDS:-0}" -eq 0 ]; then
  echo "Sin identidades válidas; obteniendo firma desde App Store Connect…"
  : "${APP_STORE_CONNECT_ISSUER_ID:?}"; : "${APP_STORE_CONNECT_KEY_IDENTIFIER:?}"; : "${APP_STORE_CONNECT_PRIVATE_KEY:?}"
  app-store-connect fetch-signing-files "$BUNDLE_ID" \
    --type IOS_APP_STORE \
    --issuer-id "$APP_STORE_CONNECT_ISSUER_ID" \
    --key-id "$APP_STORE_CONNECT_KEY_IDENTIFIER" \
    --private-key "$APP_STORE_CONNECT_PRIVATE_KEY" \
    --create
  # Importar lo que descargó fetch-signing-files
  keychain add-certificates || true
fi

echo "Identidades de firma:"
security find-identity -v -p codesigning "$KEYCHAIN_PATH" || true

echo "Perfiles disponibles:"
ls -la ~/Library/MobileDevice/Provisioning\ Profiles/ || true

mkdir -p artifacts
cp "$LOG_FILE" artifacts/ || true
echo "Setup signing DONE"
