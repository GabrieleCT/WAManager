# Script di avvio per WAManager (Backend + DB + Frontend Desktop)

echo "Chiusura eventuali processi zombie di WAManager in background..."
Stop-Process -Name node, python, dart -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Rimuove eventuali lock o flag di sola lettura impostati da OneDrive sulla cartella build
if (Test-Path "flutter_app\build") {
    attrib -r "flutter_app\build\*.*" /s /d 2>$null
}

echo "Avvio Backend (Django + DB SQLite + QCluster + WA Gateway)..."

# 1. Avvia Gateway Node.js
Start-Process powershell -ArgumentList "-NoExit -Command `"cd wa-gateway; `$env:NODE_TLS_REJECT_UNAUTHORIZED=0; npm start`"" -WindowStyle Normal

# 2. Avvia Django Web Server
Start-Process powershell -ArgumentList "-NoExit -Command `".venv\Scripts\Activate; python manage.py runserver 0.0.0.0:8082`"" -WindowStyle Normal

# 3. Avvia Django Q-Cluster (Worker)
Start-Process powershell -ArgumentList "-NoExit -Command `".venv\Scripts\Activate; python manage.py qcluster`"" -WindowStyle Normal

echo "Attendere l'avvio del backend..."
Start-Sleep -Seconds 5

echo "Avvio Frontend (Flutter Web)..."
# 4. Avvia Flutter su Web (Chrome)
Start-Process powershell -ArgumentList "-NoExit -Command `"cd flutter_app; flutter run -d chrome`"" -WindowStyle Normal

echo "=========================================================="
echo "Servizi avviati in finestre separate!"
echo "- Gateway Baileys in ascolto sulla porta 4002"
echo "- Backend API in ascolto su http://localhost:8082"
echo "- Frontend Flutter Desktop avviato"
echo "=========================================================="
