#!/usr/bin/env bash
set -euo pipefail

log_info() {
  printf '%s\n' "$1"
}

plist_path="ios/Runner/GoogleService-Info.plist"

# Ensure the environment variable is set and non-empty
if [[ -z "${GOOGLE_SERVICE_INFO_PLIST:-}" ]]; then
  log_info "GOOGLE_SERVICE_INFO_PLIST is empty"
  exit 1
fi

log_info "PLIST length: ${#GOOGLE_SERVICE_INFO_PLIST}"

value="${GOOGLE_SERVICE_INFO_PLIST}"
mkdir -p "$(dirname "$plist_path")"

# Detect base64: only base64 chars and length multiple of 4
if printf '%s' "$value" | tr -d '\n\r' | grep -Eq '^[A-Za-z0-9+/=]+$' && [ $(( ${#value} % 4 )) -eq 0 ]; then
  printf '%s' "$value" | base64 --decode > "$plist_path"
else
  printf '%s' "$value" > "$plist_path"
fi

chmod 0644 "$plist_path"

if ! plutil -lint "$plist_path" >/dev/null 2>&1; then
  log_info "plutil validation failed for $plist_path"
  exit 1
fi

file_size=$(wc -c < "$plist_path" | tr -d ' ')
checksum=$(shasum -a 256 "$plist_path" | awk '{print $1}')

log_info "PLIST file size: ${file_size} bytes"
log_info "PLIST sha256: ${checksum}"
log_info "PLIST path: $plist_path"
