# Arranca el servidor de pruebas de Próxima RP (Windows).
$Root = Split-Path -Parent $PSScriptRoot
$Exe = @("FXServer.exe", "cfx-server.exe") | ForEach-Object { Join-Path $Root "server\$_" } | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Exe) { throw "No encuentro FXServer.exe ni cfx-server.exe en server\. Ejecuta antes scripts\setup-windows.ps1" }
if (-not (Test-Path (Join-Path $Root "server-data\secrets.cfg"))) { throw "Falta server-data\secrets.cfg. Ejecuta scripts\setup-windows.ps1" }
Set-Location (Join-Path $Root "server-data")
& $Exe +exec server.cfg
