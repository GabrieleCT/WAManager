# Script per la compilazione del client Mobile (Android) di WAManager

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Avvio Build Flutter per Android (APK) in modalita' Release" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location "$scriptDir\flutter_app"

Write-Host "1. Scaricamento e verifica dipendenze..." -ForegroundColor Yellow
flutter pub get

Write-Host "2. Compilazione APK in corso (potrebbe richiedere alcuni minuti al primo avvio)..." -ForegroundColor Yellow
flutter build apk --release

if ($LASTEXITCODE -eq 0) {
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "Build completata con successo! 🎉" -ForegroundColor Green
    Write-Host "L'APK installabile si trova al seguente percorso:" -ForegroundColor Green
    Write-Host "$scriptDir\flutter_app\build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor White
    Write-Host "==========================================================" -ForegroundColor Green
} else {
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host "❌ Errore durante la compilazione. Controlla i log qui sopra." -ForegroundColor Red
    Write-Host "==========================================================" -ForegroundColor Red
}
