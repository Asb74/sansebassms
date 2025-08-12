#!/bin/bash
set +e  # No detener el script si ocurre un error

echo "===== POST BUILD SCRIPT INICIADO =====" > build_log.txt

echo "[1] Versión de Flutter:" >> build_log.txt
flutter --version >> build_log.txt 2>&1

echo "[2] Directorio iOS antes de pod install:" >> build_log.txt
ls ios >> build_log.txt 2>&1

echo "[3] Intentando pod install..." >> build_log.txt
cd ios
pod install >> ../build_log.txt 2>&1
echo "[4] Versiones de gRPC/BoringSSL/abseil/Firebase:" >> ../build_log.txt
grep -E "gRPC|BoringSSL|abseil|Firebase" Podfile.lock >> ../build_log.txt 2>&1
cd ..

echo "[5] flutter pub get..." >> build_log.txt
flutter pub get >> build_log.txt 2>&1

echo "[6] Contenido de .flutter-plugins-dependencies:" >> build_log.txt
cat .flutter-plugins-dependencies >> build_log.txt 2>&1

echo "[7] Contenido de pubspec.yaml:" >> build_log.txt
cat pubspec.yaml >> build_log.txt 2>&1

echo "===== POST BUILD SCRIPT FINALIZADO =====" >> build_log.txt
