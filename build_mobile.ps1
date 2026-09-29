# Script per la compilazione del client Mobile (Android) di WAManager

echo "=========================================================="
echo "Avvio Build Flutter per Android (APK) in modalita' Release"
echo "=========================================================="

cd flutter_app

echo "1. Pulizia cache e build precedenti..."
flutter clean

echo "2. Scaricamento dipendenze..."
flutter pub get

echo "3. Compilazione APK in corso (potrebbe richiedere alcuni minuti)..."
flutter build apk --release

if ($LASTEXITCODE -eq 0) {
    echo "=========================================================="
    echo "Build completata con successo! 🎉"
    echo "L'APK si trova al seguente percorso:"
    echo ".\flutter_app\build\app\outputs\flutter-apk\app-release.apk"
    echo "=========================================================="
} else {
    echo "=========================================================="
    echo "❌ Errore durante la compilazione. Controlla i log qui sopra."
    echo "Assicurati di aver installato l'SDK di Android."
    echo "=========================================================="
}
