@echo off
title WAManager - Build Mobile APK (Android)
echo ==========================================================
echo Avvio Build Flutter per Android (APK) in modalita Release
echo ==========================================================
echo.

cd /d "%~dp0flutter_app"

echo [1/2] Scaricamento e verifica dipendenze...
call flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo Errore durante flutter pub get.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [2/2] Compilazione APK release in corso (puo richiedere alcuni minuti al primo avvio)...
call flutter build apk --release
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ==========================================================
    echo [ERRORE] Compilazione fallita. Controlla i log qui sopra.
    echo ==========================================================
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo ==========================================================
echo Build completata con successo!
echo File APK generato pronto per l'installazione su Android:
echo %~dp0flutter_app\build\app\outputs\flutter-apk\app-release.apk
echo ==========================================================
echo.
pause
