# ============================================================
# ejecutar.ps1 · punto de entrada único para Windows (PowerShell)
# Hace lo mismo que ejecutar.sh:
#   1. Registra el ambiente del equipo anfitrión y de Docker
#   2. Recrea las bases desde cero (datos idénticos en cada ejecución)
#   3. Corre las mediciones de PostgreSQL y luego las de MongoDB
#   4. Deja todo en evidencias\<fecha_hora>\
# Si PowerShell bloquea el script:  powershell -ExecutionPolicy Bypass -File .\ejecutar.ps1
# ============================================================
$ErrorActionPreference = 'Stop'
Set-Location -Path $PSScriptRoot

$env:RUN_ID = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$out = Join-Path 'evidencias' $env:RUN_ID
New-Item -ItemType Directory -Force -Path $out | Out-Null
$hostFile = Join-Path $out '00_ambiente_host.txt'

function Invoke-Paso([string]$titulo, [scriptblock]$accion) {
  Write-Host "==> $titulo"
  & $accion
  if ($LASTEXITCODE -ne 0) { throw "Falló: $titulo (código $LASTEXITCODE)" }
}

Write-Host "==> Ejecución $($env:RUN_ID)"
$cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1)
$os  = Get-CimInstance Win32_OperatingSystem
$ramGb = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
@(
  "Fecha y hora: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
  "Sistema del anfitrión: $($os.Caption) $($os.Version)"
  "CPU del anfitrión: $($cpu.Name) ($($cpu.NumberOfCores) núcleos, $($cpu.NumberOfLogicalProcessors) hilos)"
  "RAM del anfitrión: $ramGb GB"
  ""
  "--- docker version"
  (docker version --format 'Cliente {{.Client.Version}} · Servidor {{.Server.Version}} ({{.Server.Os}}/{{.Server.Arch}})')
  "--- docker compose version"
  (docker compose version --short)
  "--- docker info (recursos totales disponibles para Docker)"
  (docker info --format "Sistema: {{.OperatingSystem}}`nKernel: {{.KernelVersion}}`nCPUs para Docker: {{.NCPU}}`nRAM para Docker: {{.MemTotal}} bytes")
) | Set-Content -Encoding UTF8 $hostFile

Write-Host "==> Recreando contenedores y datos desde cero"
docker compose down -v --remove-orphans 2>$null | Out-Null
Invoke-Paso 'Levantando PostgreSQL y MongoDB (carga inicial, menos de 1 minuto)' { docker compose up -d --wait postgres mongo }
Invoke-Paso 'Midiendo PostgreSQL (unos 2 minutos)' { docker compose run --rm runner-pg }
Invoke-Paso 'Midiendo MongoDB' { docker compose run --rm --no-deps runner-mongo }

Add-Content -Encoding UTF8 $hostFile ""
Add-Content -Encoding UTF8 $hostFile "--- Límites aplicados a cada contenedor (NanoCpus / Memoria en bytes)"
foreach ($s in 'postgres', 'mongo') {
  $id = docker compose ps -q $s
  Add-Content -Encoding UTF8 $hostFile "${s}: $(docker inspect --format '{{.HostConfig.NanoCpus}} / {{.HostConfig.Memory}}' $id)"
}

Write-Host ""
Write-Host "==> Listo. Evidencias en $out\ (empieza por comparacion.md)"
Write-Host "    Las bases siguen arriba: PostgreSQL en localhost:5432, MongoDB en localhost:27017"
Write-Host "    Para apagarlas y borrar sus datos: docker compose down -v"
