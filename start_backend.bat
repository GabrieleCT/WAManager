@echo off
title Django Backend - WAManager (Porta 50082)
cd /d "%~dp0"
echo ==========================================================
echo Chiusura eventuali processi Python bloccati in background...
taskkill /F /IM python.exe 2>nul
timeout /t 1 /nobreak >nul
echo Avvio Django Web Server su 0.0.0.0:50082...
echo ==========================================================
".venv\Scripts\python.exe" manage.py runserver 0.0.0.0:50082
pause
