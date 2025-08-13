#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LOG_FILE="$ROOT_DIR/codemagic_setup_signing.log"
: > "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "== Setup signing =="

require() { local n="$1"; [ -n "${!n:-}" ] || { echo "ERROR: falta $n"; exit 2; }; }
require APPLE_TEAM_ID
require BUNDLE_ID

# Create ephemeral keychain (never touch login)
KEYCHAIN_DIR="$HOME/Library/codemagic-cli-tools/keychains"
mkdir -p "$KEYCHAIN_DIR"
KEYCHAIN_NAME="cm_$(date +%s)_$$.keychain-db"
KEYCHAIN_PATH="$KEYCHAIN_DIR/$KEYCHAIN_NAME"
KEYCHAIN_PASSWORD="${KEYCHAIN_PASSWORD:-cm_tmp_$(date +%s)}"

echo "Creando llavero efímero: $KEYCHAIN_PATH"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" || true
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH" || true
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

# Make it default and only one in search list
security list-keychains -d user -s "$KEYCHAIN_PATH"
security default-keychain -s "$KEYCHAIN_PATH"

# Optional manual import via P12 provided in env vars
if [ -n "${CERTIFICATE_P12_BASE64:-}" ]; then
  echo "Importando P12 aportado…"
  echo "$CERTIFICATE_P12_BASE64" | base64 --decode > dist.p12
  : "${P12_PASSWORD:?Missing P12_PASSWORD}"
  security import dist.p12 -k "$KEYCHAIN_PATH" -P "$P12_PASSWORD" -T /usr/bin/codesign
fi

# Import certificates downloaded by fetch-signing-files
echo "Importando certificados con keychain add-certificates…"
keychain add-certificates || true

# Check for identities
IDS="$(security find-identity -v -p codesigning "$KEYCHAIN_PATH" | grep -cE 'Apple (Distribution|Development)' || true)"
echo "Identidades encontradas: $IDS"
if [ "${IDS:-0}" -eq 0 ]; then
  echo "Sin identidades válidas. Generando certificado de distribución temporal…"
  TMP_DIR="$(mktemp -d)"
  pushd "$TMP_DIR" >/dev/null
  openssl req -new -newkey rsa:2048 -nodes -keyout temp.key -out temp.csr -subj "/CN=Codemagic/OU=${APPLE_TEAM_ID}/O=${APPLE_TEAM_ID}/C=US"
  app-store-connect certificates create \
    --type IOS_DISTRIBUTION \
    --csr-file temp.csr \
    --certificate-output-file temp.cer
  openssl x509 -in temp.cer -out temp.pem -inform DER
  P12_PWD="${P12_PASSWORD:-temp_pass}"
  openssl pkcs12 -export -inkey temp.key -in temp.pem -out temp.p12 -password "pass:$P12_PWD"
  security import temp.p12 -k "$KEYCHAIN_PATH" -P "$P12_PWD" -T /usr/bin/codesign
  popd >/dev/null
fi

# Final diagnostics
security find-identity -v -p codesigning "$KEYCHAIN_PATH" || true
ls -la ~/Library/MobileDevice/Provisioning\ Profiles/ || true

# Apply provisioning profiles using default keychain
xcode-project use-profiles || true

mkdir -p artifacts
cp "$LOG_FILE" artifacts/ || true

echo "Setup signing DONE"
