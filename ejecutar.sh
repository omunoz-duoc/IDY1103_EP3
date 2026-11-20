#!/usr/bin/env bash
# ============================================================
# ejecutar.sh · punto de entrada único (Linux, macOS o Git Bash en Windows)
#
#   1. Registra el ambiente del equipo anfitrión y de Docker
#   2. Recrea las bases desde cero (datos idénticos en cada ejecución)
#   3. Corre las mediciones de PostgreSQL y luego las de MongoDB
#   4. Deja todo en evidencias/<fecha_hora>/
#
# Las bases quedan arriba al terminar, para revisarlas con pgAdmin o Compass.
# Para apagarlas y borrar sus datos: docker compose down -v
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

RUN_ID="$(date +%Y-%m-%d_%H%M%S)"
OUT="evidencias/${RUN_ID}"
export RUN_ID HOST_UID="$(id -u)" HOST_GID="$(id -g)"
mkdir -p "${OUT}"

echo "==> Ejecución ${RUN_ID}"
echo "==> Registrando ambiente del anfitrión en ${OUT}/00_ambiente_host.txt"
{
  echo "Fecha y hora: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "Sistema del anfitrión: $(uname -srm)"
  echo
  echo "--- docker version"
  docker version --format 'Cliente {{.Client.Version}} · Servidor {{.Server.Version}} ({{.Server.Os}}/{{.Server.Arch}})'
  echo "--- docker compose version"
  docker compose version --short
  echo "--- docker info (recursos totales disponibles para Docker)"
  docker info --format 'Sistema: {{.OperatingSystem}}
Kernel: {{.KernelVersion}}
CPUs para Docker: {{.NCPU}}
RAM para Docker: {{.MemTotal}} bytes'
} > "${OUT}/00_ambiente_host.txt"

echo "==> Recreando contenedores y datos desde cero"
docker compose down -v --remove-orphans > /dev/null 2>&1 || true
docker compose up -d --wait postgres mongo

echo "==> Midiendo PostgreSQL (unos 2 minutos)"
docker compose run --rm runner-pg
echo "==> Midiendo MongoDB"
docker compose run --rm --no-deps runner-mongo

{
  echo
  echo "--- Límites aplicados a cada contenedor (NanoCpus / Memoria en bytes)"
  for s in postgres mongo; do
    echo "${s}: $(docker inspect --format '{{.HostConfig.NanoCpus}} / {{.HostConfig.Memory}}' "$(docker compose ps -q "${s}")")"
  done
} >> "${OUT}/00_ambiente_host.txt"

echo
echo "==> Listo. Evidencias en ${OUT}/ (empieza por comparacion.md)"
echo "    Las bases siguen arriba: PostgreSQL en localhost:${PG_PORT:-5432}, MongoDB en localhost:${MONGO_PORT:-27017}"
echo "    Para apagarlas y borrar sus datos: docker compose down -v"
