<#
  Próxima RP — instalación del entorno de pruebas en Windows.
  Uso (PowerShell, desde la raíz del repo):
    .\scripts\setup-windows.ps1
  Busca solo el build RECOMENDADO de FXServer en la API oficial de versiones
  (la misma que usa txAdmin). Para forzar otro build: -ArtifactUrl "<enlace>".
#>
param([string]$ArtifactUrl = "")
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Server = Join-Path $Root "server"
$Data = Join-Path $Root "server-data"
$Cfx = Join-Path $Data "resources\[cfx]"

function Step($t) { Write-Host "`n» $t" -ForegroundColor Cyan }

Step "Comprobando herramientas"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "Falta Git: https://git-scm.com/download/win" }
$HasNode = [bool](Get-Command node -ErrorAction SilentlyContinue)
if (-not $HasNode) { Write-Host "  Node.js no está instalado (opcional: tests, comando pxd y arte de la marca)." -ForegroundColor Yellow }

Step "Binarios de FXServer"
New-Item -ItemType Directory -Force -Path $Server | Out-Null
$Exe = @("FXServer.exe", "cfx-server.exe") | ForEach-Object { Join-Path $Server $_ } | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($Exe) {
  Write-Host "  Ya existen: $Exe"
} else {
  if (-not $ArtifactUrl) {
    try {
      $Info = Invoke-RestMethod "https://changelogs-live.fivem.net/api/changelog/versions/win32/server"
      $ArtifactUrl = $Info.recommended_download
      Write-Host "  Build recomendado: $($Info.recommended)"
    } catch { Write-Host "  No se pudo consultar la API de versiones: $($_.Exception.Message)" -ForegroundColor Yellow }
  }
  if ($ArtifactUrl) {
    $Archive = Join-Path $Server "artifact.7z"
    Invoke-WebRequest -Uri $ArtifactUrl -OutFile $Archive
    tar -xf $Archive -C $Server
    if ($LASTEXITCODE -ne 0) { throw "No se pudo descomprimir con tar. Abre $Archive con 7-Zip y extrae su contenido en $Server" }
    Remove-Item $Archive
    Write-Host "  Extraídos en $Server"
  } else {
    Write-Host "  Descarga el build RECOMENDADO para Windows desde https://docs.fivem.net/docs/server-download/" -ForegroundColor Yellow
    Write-Host "  y extrae el .7z dentro de $Server (o vuelve a ejecutar con -ArtifactUrl)." -ForegroundColor Yellow
  }
}

Step "Recursos base (cfx-server-data)"
if (Test-Path $Cfx) {
  Write-Host "  Ya existen en $Cfx"
} else {
  $Tmp = Join-Path $env:TEMP ("cfx-server-data-" + [guid]::NewGuid())
  git clone --depth 1 https://github.com/citizenfx/cfx-server-data.git $Tmp
  New-Item -ItemType Directory -Force -Path $Cfx | Out-Null
  Copy-Item -Recurse -Force (Join-Path $Tmp "resources\*") $Cfx
  Remove-Item -Recurse -Force $Tmp
}

Step "Secretos (secrets.cfg y .env)"
$Secrets = Join-Path $Data "secrets.cfg"
if (-not (Test-Path $Secrets)) {
  $Bytes = New-Object byte[] 24
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($Bytes)
  $Token = -join ($Bytes | ForEach-Object { $_.ToString("x2") })
  (Get-Content (Join-Path $Data "secrets.cfg.example") -Raw).Replace("GENERA_UN_TOKEN_LARGO", $Token) | Set-Content -Encoding UTF8 $Secrets
  $EnvFile = Join-Path $Root ".env"
  if (-not (Test-Path $EnvFile)) {
    (Get-Content (Join-Path $Root ".env.example") -Raw).Replace("PXD_TOKEN=", "PXD_TOKEN=$Token") | Set-Content -Encoding UTF8 $EnvFile
  }
  Write-Host "  Creado secrets.cfg con un token nuevo (también en .env para el comando pxd)."
} else { Write-Host "  secrets.cfg ya existe; no se toca." }

if ($HasNode) {
  Step "Arte de la marca (fondo y vídeo de la pantalla de carga)"
  node (Join-Path $Root "scripts\fetch-brand-assets.mjs")
}

Write-Host "`nListo. Siguientes pasos:" -ForegroundColor Green
Write-Host "  1. Edita server-data\permissions.cfg y añade tu identificador a group.admin."
Write-Host "  2. Arranca:  .\scripts\run-windows.ps1"
Write-Host "  3. En FiveM: F8 → connect localhost:30120"
