@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Proxima RP - Montar el servidor de Discord
where node >nul 2>nul || (echo Falta Node.js: https://nodejs.org & pause & exit /b 1)
if not exist .env (echo Primero abre 1-configurar. & pause & exit /b 1)
if not exist node_modules call npm install --omit=dev
echo Revisando tu servidor de Discord ^(todavia no se cambia nada^)...
echo.
node src\setup.js || (pause & exit /b 1)
echo.
choice /C SN /M "Crear todo esto en tu Discord"
if errorlevel 2 (
  echo No se ha cambiado nada.
  pause
  exit /b 0
)
node src\setup.js --aplicar --icono
echo.
echo Si todo salio bien, abre 3-encender-bot.
pause
