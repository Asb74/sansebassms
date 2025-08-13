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

import_p12_from_env() {
  [ -n "${CERTIFICATE_P12_BASE64:-}" ] || return 1
  echo "Importando P12 aportado…"
  # Guardado y sanitizado mínimo (ignora basura si hubiera)
  if ! printf "%s" "$CERTIFICATE_P12_BASE64" | base64 --decode --ignore-garbage > dist.p12 2>/dev/null; then
    echo "WARN: CERTIFICATE_P12_BASE64 inválido (no es base64)."
    return 1
  fi
  : "${P12_PASSWORD:?Missing P12_PASSWORD}"
  security import dist.p12 -k "$(keychain get-default | awk 'END{print $NF}')" -P "$P12_PASSWORD" -T /usr/bin/codesign
}

# Inicializar llavero efímero (usar CLI oficial de Codemagic)
keychain initialize
KEYCHAIN_PATH="$(keychain get-default | awk 'END{print $NF}')"
echo "Default keychain: $KEYCHAIN_PATH"

# Importación manual opcional
import_p12_from_env || true

# Comprobar identidades de firma
IDS=$(security find-identity -v -p codesigning "$KEYCHAIN_PATH" | grep -cE 'Apple (Distribution|Development)' || true)
if [ "${IDS:-0}" -eq 0 ]; then
  echo "Sin identidades válidas; obteniendo firma desde App Store Connect…"
  : "${APP_STORE_CONNECT_ISSUER_ID:?}"
  : "${APP_STORE_CONNECT_KEY_IDENTIFIER:?}"
  : "${APP_STORE_CONNECT_PRIVATE_KEY:?}"
  app-store-connect fetch-signing-files "$BUNDLE_ID" \
    --type IOS_APP_STORE \
    --issuer-id "$APP_STORE_CONNECT_ISSUER_ID" \
    --key-id "$APP_STORE_CONNECT_KEY_IDENTIFIER" \
    --private-key "$APP_STORE_CONNECT_PRIVATE_KEY" \
    --create
  keychain add-certificates || true
fi

echo "Identidades de firma:"
security find-identity -v -p codesigning "$KEYCHAIN_PATH" || true

echo "Perfiles disponibles:"
ls -la ~/Library/MobileDevice/Provisioning\ Profiles/ || true

mkdir -p "$ROOT_DIR/artifacts"
cp "$LOG_FILE" "$ROOT_DIR/artifacts/" || true
echo "Setup signing DONE"
