#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LOG_FILE="$ROOT_DIR/codemagic_setup_signing.log"
: > "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "== Setup signing =="

# Vars requeridas
require() { local n="$1"; [ -n "${!n:-}" ] || { echo "ERROR: falta $n"; exit 2; }; }
require APPLE_TEAM_ID
require BUNDLE_ID

# Creamos llavero efímero (NUNCA el login)
KEYCHAIN_DIR="$HOME/Library/codemagic-cli-tools/keychains"
mkdir -p "$KEYCHAIN_DIR"
KEYCHAIN_NAME="cm_$(date +%s)_$$.keychain-db"
KEYCHAIN_PATH="$KEYCHAIN_DIR/$KEYCHAIN_NAME"
KEYCHAIN_PASSWORD="${KEYCHAIN_PASSWORD:-cm_tmp_$(date +%s)}"

echo "Creando llavero efímero: $KEYCHAIN_PATH"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" || true
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH" || true
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security list-keychains -d user -s "$KEYCHAIN_PATH"

# Opción manual: P12 aportado por env
if [ -n "${CERTIFICATE_P12_BASE64:-}" ]; then
  echo "Importando P12 aportado…"
  echo "$CERTIFICATE_P12_BASE64" | base64 --decode > dist.p12
  : "${P12_PASSWORD:?Missing P12_PASSWORD}"
  security import dist.p12 -k "$KEYCHAIN_PATH" -P "$P12_PASSWORD" -T /usr/bin/codesign
fi

# Opción automática: usar lo descargado por pre-build (fetch-signing-files)
# y/o reintentar importación genérica.
if ! security find-identity -v -p codesigning "$KEYCHAIN_PATH" | grep -q "Apple Distribution"; then
  echo "Intentando importar certificados con keychain add-certificates…"
  keychain add-certificates --keychain "$KEYCHAIN_PATH" || true
fi

# Diagnóstico: debe existir al menos 1 identidad válida
echo "Identidades de firma en $KEYCHAIN_PATH:"
security find-identity -v -p codesigning "$KEYCHAIN_PATH" || true

# Aplicamos perfiles al proyecto (usa perfiles de ~/Library/MobileDevice/Provisioning Profiles)
echo "Aplicando perfiles con xcode-project use-profiles…"
xcode-project use-profiles --keychain "$KEYCHAIN_PATH"

# Más diagnóstico útil
ls -la ~/Library/MobileDevice/Provisioning\ Profiles/ || true

# Exportar log como artifact
mkdir -p artifacts
cp "$LOG_FILE" artifacts/ || true
echo "Setup signing DONE"
