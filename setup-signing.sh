#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LOG_FILE="$ROOT_DIR/codemagic_setup_signing.log"
: > "$LOG_FILE"; exec > >(tee -a "$LOG_FILE") 2>&1

echo "== Setup signing (auto) =="

need(){ [ -n "${!1:-}" ] || { echo "ERROR: falta $1"; exit 2; }; }
need APP_STORE_CONNECT_ISSUER_ID
need APP_STORE_CONNECT_KEY_IDENTIFIER
need APP_STORE_CONNECT_PRIVATE_KEY     # .p8 (EC) para API ASC
need APPLE_CERTIFICATE_PRIVATE_KEY     # RSA 2048 PEM sin passphrase (para emitir el cert)
need APPLE_TEAM_ID
need BUNDLE_ID

# Llavero por defecto de Codemagic
keychain initialize
KEYCHAIN_PATH="$(keychain get-default | awk 'END{print $NF}')"
echo "Default keychain: $KEYCHAIN_PATH"

# (Nuevo) Si hay un .mobileprovision en Base64, instálalo (sin usar /dev/stdin)
if [[ -n "${IOS_APPSTORE_PROFILE_B64:-}" ]]; then
  echo "Instalando perfil desde IOS_APPSTORE_PROFILE_B64..."
  INSTALL_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
  mkdir -p "$INSTALL_DIR"

  TMP_DIR="$(mktemp -d)"
  echo "$IOS_APPSTORE_PROFILE_B64" | base64 --decode > "$TMP_DIR/profile.mobileprovision"

  # Copiar con nombre fijo (evita parsear UUID para no depender de /dev/stdin)
  DEST="$INSTALL_DIR/appstore.mobileprovision"
  cp -f "$TMP_DIR/profile.mobileprovision" "$DEST"
  echo "✅ Installed provisioning profile at: $DEST"

  # Mostrar entorno APNs del perfil (esperado: production o development)
  DECODED="$TMP_DIR/decoded.plist"
  /usr/bin/security cms -D -i "$DEST" > "$DECODED" 2>/dev/null || true
  APS=$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:aps-environment' "$DECODED" 2>/dev/null || echo "unknown")
  echo "aps-environment del perfil: $APS"
fi

# Determinar flag de clave privada para fetch
CERT_FLAG="--certificate-key"
app-store-connect fetch-signing-files --help | grep -q -- "--certificate-key" || CERT_FLAG="--cert-private-key"

# Traer certificados (y perfiles, si hacen falta) desde App Store Connect
app-store-connect fetch-signing-files "$BUNDLE_ID" \
  --type IOS_APP_STORE \
  --issuer-id "$APP_STORE_CONNECT_ISSUER_ID" \
  --key-id "$APP_STORE_CONNECT_KEY_IDENTIFIER" \
  --private-key "$APP_STORE_CONNECT_PRIVATE_KEY" \
  $CERT_FLAG "$APPLE_CERTIFICATE_PRIVATE_KEY" \
  --create

# Importar al llavero y aplicar perfiles al proyecto
keychain add-certificates || true
xcode-project use-profiles

echo "Identidades de firma:"
security find-identity -v -p codesigning "$KEYCHAIN_PATH" || true

echo "Perfiles disponibles:"
ls -la ~/Library/MobileDevice/Provisioning\ Profiles/ || true

mkdir -p artifacts
cp "$LOG_FILE" artifacts/ || true
echo "Setup signing DONE"
