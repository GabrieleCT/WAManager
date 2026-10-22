@echo off
title WhatsApp Gateway - WAManager (Porta 4002)
cd /d "%~dp0wa-gateway"
echo ==========================================================
echo Avvio WhatsApp Gateway (Baileys) sulla porta 4002...
echo ==========================================================
set NODE_TLS_REJECT_UNAUTHORIZED=0
node index.js
pause

