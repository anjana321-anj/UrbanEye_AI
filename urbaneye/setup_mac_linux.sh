#!/usr/bin/env bash
# ============================================================
#  UrbanEye one-time setup (macOS / Linux)
#  Generates Android/Web platform scaffolding for YOUR Flutter
#  version without overwriting UrbanEye's files, then gets packages.
# ============================================================
set -e
cd "$(dirname "$0")"
echo "[1/3] Checking Flutter..."
flutter --version
echo "[2/3] Generating platform files (android, web)..."
flutter create --org com.urbaneye --project-name urbaneye --platforms=android,web .
echo "[3/3] Getting packages..."
flutter pub get
echo
echo "Done! Open this folder in Android Studio and press Run, or: flutter run"
echo "Admin console in a desktop browser: flutter run -d chrome"
