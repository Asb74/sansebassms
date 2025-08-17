#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="prebuild_plist.log"
PLIST_PATH="ios/Runner/GoogleService-Info.plist"

# clean previous log
: > "$LOG_FILE"

log() {
  echo "$1" | tee -a "$LOG_FILE"
}

log "Inicio del script de generación de GoogleService-Info.plist"

log "Verificando variable de entorno GOOGLE_SERVICE_INFO_PLIST"
if [[ -z "${GOOGLE_SERVICE_INFO_PLIST:-}" ]]; then
  log "Variable GOOGLE_SERVICE_INFO_PLIST no existe o está vacía. Continuando sin generar el archivo."
  log "Fin del script de generación de GoogleService-Info.plist"
  exit 0
fi
log "Variable encontrada"

log "Decodificando base64"
tmpfile="$(mktemp)"
echo "$GOOGLE_SERVICE_INFO_PLIST" | base64 --decode > "$tmpfile"
log "Decodificación completada"

log "Guardando archivo en $PLIST_PATH"
mkdir -p "$(dirname "$PLIST_PATH")"
mv "$tmpfile" "$PLIST_PATH"
log "Archivo guardado en $PLIST_PATH"

log "Fin del script de generación de GoogleService-Info.plist"

