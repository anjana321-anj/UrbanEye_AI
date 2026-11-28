@echo off
REM ============================================================
REM  UrbanEye one-time setup (Windows)
REM  Generates the Android / Web platform scaffolding that matches
REM  YOUR installed Flutter version (existing files are NOT overwritten,
REM  so UrbanEye's AndroidManifest permissions and icons are kept),
REM  then downloads all packages.
REM ============================================================
cd /d "%~dp0"
echo.
echo [1/3] Checking Flutter...
call flutter --version || (echo Flutter is not on PATH. Install Flutter first. & pause & exit /b 1)
echo.
echo [2/3] Generating platform files (android, web)...
call flutter create --org com.urbaneye --project-name urbaneye --platforms=android,web .
echo.
echo [3/3] Getting packages...
call flutter pub get
echo.
echo Done! Open this folder in Android Studio, pick a device, and press Run.
echo   Or run:  flutter run
echo   Admin console on desktop browser:  flutter run -d chrome
pause
