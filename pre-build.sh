#!/usr/bin/env bash
set -Eeuo pipefail

# Global log file at repository root
ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LOG_FILE="$ROOT_DIR/codemagic_prebuild.log"
mkdir -p "$ROOT_DIR"
: >"$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting pre-build script"

# Ensure required environment variables are present
missing_env=false
for var in APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_KEY_IDENTIFIER \
           APP_STORE_CONNECT_PRIVATE_KEY BUNDLE_ID; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Missing required env var: $var"
    missing_env=true
  fi
done

if [ "$missing_env" = true ]; then
  echo "Pre-build aborted due to missing environment variables." >&2
  mkdir -p artifacts
  cp "$LOG_FILE" artifacts/ || true
  exit 2
fi

echo "Flutter: $(flutter --version)"
echo "Ruby: $(ruby -v)"
echo "CocoaPods: $(pod --version)"
xcodebuild -version

# Fetch project dependencies and iOS artifacts
flutter pub get
flutter precache --ios

# Force iOS 15 deployment target in the Xcode project
/usr/bin/sed -i '' -E "s/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+/IPHONEOS_DEPLOYMENT_TARGET = 15.0/g" \
  ios/Runner.xcodeproj/project.pbxproj

# Install CocoaPods
pushd ios >/dev/null
pod install --repo-update
popd >/dev/null

# Fetch signing files using explicit credentials
app-store-connect fetch-signing-files "$BUNDLE_ID" \
  --type IOS_APP_STORE \
  --issuer-id "$APP_STORE_CONNECT_ISSUER_ID" \
  --key-id "$APP_STORE_CONNECT_KEY_IDENTIFIER" \
  --private-key "$APP_STORE_CONNECT_PRIVATE_KEY" \
  --create

# Initialize keychain and attempt to import existing certificates
keychain initialize
CERT_LOG=$(mktemp)
if ! keychain add-certificates > >(tee "$CERT_LOG") 2>&1; then
  true # continue; errors handled by checking log
fi

if grep -q "Cannot save Signing Certificates without certificate private key" "$CERT_LOG"; then
  echo "No private key for existing certificates. Generating new distribution certificate." >&2
  openssl genrsa -out dist.key 2048
  openssl req -new -key dist.key -out dist.csr -subj "/CN=Dist Cert"
  app-store-connect certificates create \
    --type IOS_DISTRIBUTION \
    --csr-file dist.csr \
    --output dist.cer \
    --issuer-id "$APP_STORE_CONNECT_ISSUER_ID" \
    --key-id "$APP_STORE_CONNECT_KEY_IDENTIFIER" \
    --private-key "$APP_STORE_CONNECT_PRIVATE_KEY"

  if [ -z "${P12_PASSWORD:-}" ]; then
    P12_PASSWORD="$(openssl rand -base64 12)"
    mkdir -p artifacts
    echo "$P12_PASSWORD" > artifacts/secret_hint.txt
    echo "Generated random P12_PASSWORD and stored hint at artifacts/secret_hint.txt"
  fi

  openssl pkcs12 -export -inkey dist.key -in dist.cer -out dist.p12 \
    -passout pass:"$P12_PASSWORD"
  security import dist.p12 -k "$HOME/Library/codemagic-cli-tools/keychains/login.keychain-db" \
    -P "$P12_PASSWORD" -T /usr/bin/codesign
fi

# Configure Xcode project with fetched provisioning profiles
xcode-project use-profiles

# Diagnostics for debugging signing issues
security find-identity -v -p codesigning || true
ls -la "$HOME/Library/MobileDevice/Provisioning Profiles/" || true

# Collect useful artifacts for debugging
mkdir -p artifacts
cp ios/Podfile.lock artifacts/ || true
grep -E "gRPC|BoringSSL|Firebase|abseil" ios/Podfile.lock | tee artifacts/pods-versions.txt || true
cp "$LOG_FILE" artifacts/ || true

echo "Pre-build script completed"
