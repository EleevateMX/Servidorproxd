@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Proxima RP - Configurar el bot
where node >nul 2>nul || (
  echo.
  echo Falta Node.js. Descargalo de https://nodejs.org ^(boton LTS^), instalalo y vuelve a abrir este archivo.
  pause
  exit /b 1
)
if not exist node_modules (
  echo Instalando lo que necesita el bot ^(solo la primera vez^)...
  call npm install --omit=dev
)
node src\configure.js
echo.
pause
