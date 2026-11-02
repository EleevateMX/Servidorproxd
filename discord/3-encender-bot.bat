@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Proxima RP - Bot encendido (no cierres esta ventana)
where node >nul 2>nul || (echo Falta Node.js: https://nodejs.org & pause & exit /b 1)
if not exist node_modules call npm install --omit=dev
echo El bot funciona mientras esta ventana este abierta. Para apagarlo, cierrala.
echo.
node src\bot.js
echo.
echo El bot se ha detenido.
pause
