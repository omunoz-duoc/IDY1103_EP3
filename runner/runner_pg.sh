#!/usr/bin/env bash
# ============================================================
# runner_pg.sh · genera TODAS las evidencias de PostgreSQL sin pasos manuales
#
#   1. Ambiente del servidor y verificación de la carga
#   2. Escenario A (ANTES) y B (solo reescritura), sin índices
#   3. Aplica 03_optimizaciones.sql
#   4. Escenario C (solo índices) y D (DESPUÉS)
#   5. Costo de los índices (tamaño y efecto en INSERT) y comparacion.md
# ============================================================
set -euo pipefail

RUN_ID="${RUN_ID:-manual}"
OUT="/evidencias/${RUN_ID}"
PLANES="${OUT}/planes"
SQL_DIR="/scripts/postgres"
mkdir -p "${PLANES}"

export PGHOST="${PGHOST:-postgres}" PGUSER="${POSTGRES_USER}" PGPASSWORD="${POSTGRES_PASSWORD}" PGDATABASE="${POSTGRES_DB}"
PSQL=(psql -X -q -v ON_ERROR_STOP=1 -v run="${RUN_ID}")

log() { echo "[runner-pg $(date +%H:%M:%S)] $*"; }

# Consulta sin comentarios ni líneas vacías (los comentarios quedan en el archivo fuente)
leer() { grep -v '^\s*--' "${SQL_DIR}/consultas/$1.sql" | sed '/^\s*$/d'; }

medir() {   # medir Q1 A q1_antes
  local consulta="$1" escenario="$2" archivo="$3"
  "${PSQL[@]}" -v q="$(leer "${archivo}")" -v c="${consulta}" -v e="${escenario}" \
    <<< "SELECT medicion.medir(:'run', :'c', :'e', :'q', 3);" > /dev/null
}

guardar_plan() {   # guardar_plan Q1 A q1_antes destino.txt
  local consulta="$1" escenario="$2" archivo="$3" destino="$4"
  {
    echo "-- ${consulta} · escenario ${escenario} · ejecución ${RUN_ID}"
    echo "-- Archivo: scripts/postgres/consultas/${archivo}.sql"
    echo
    cat "${SQL_DIR}/consultas/${archivo}.sql"
    echo
    echo
    echo "-- EXPLAIN (ANALYZE, BUFFERS) ---------------------------------"
    "${PSQL[@]}" -v q="$(leer "${archivo}")" <<< "EXPLAIN (ANALYZE, BUFFERS) :q;"
  } > "${destino}"
  "${PSQL[@]}" -At -v c="${consulta}" -v e="${escenario}" \
    <<< "SELECT plan FROM medicion.resultados WHERE ejecucion = :'run' AND consulta = :'c' AND escenario = :'e' ORDER BY corrida DESC LIMIT 1;" \
    > "${destino%.txt}.json"
}

log "Esperando a PostgreSQL..."
until pg_isready -q; do sleep 2; done

log "Preparando funciones de medición"
"${PSQL[@]}" -f /runner/medicion.sql > /dev/null
"${PSQL[@]}" <<< "DELETE FROM medicion.resultados WHERE ejecucion = :'run';
                  DELETE FROM medicion.escrituras WHERE ejecucion = :'run';
                  DELETE FROM medicion.indices    WHERE ejecucion = :'run';" > /dev/null
# Garantiza el estado ANTES aunque se repita la ejecución sin recrear la base
"${PSQL[@]}" -f "${SQL_DIR}/99_revertir.sql" > /dev/null 2>&1

log "Registrando ambiente"
{
  echo "# Ambiente de ejecución · ${RUN_ID}"
  echo
  echo "Generado automáticamente el $(date '+%Y-%m-%d %H:%M:%S %Z'). Los datos del equipo anfitrión y de Docker están en \`00_ambiente_host.txt\` (los genera ejecutar.sh / ejecutar.ps1)."
  echo
  "${PSQL[@]}" -f /runner/ambiente_pg.sql
  echo
  echo "Kernel visto desde el contenedor: \`$(uname -srm)\`"
} > "${OUT}/00_ambiente.md"

log "Verificación de carga (COUNT)"
"${PSQL[@]}" -f "${SQL_DIR}/00_verificacion.sql" > "${OUT}/01_verificacion.txt"

log "Costo de inserción sin índices"
"${PSQL[@]}" <<< "SELECT medicion.costo_insercion(:'run', 'sin_indices');" > /dev/null

for n in 1 2 3; do
  log "Q${n}: escenario A (ANTES) y B (solo reescritura)"
  medir "Q${n}" A "q${n}_antes"
  guardar_plan "Q${n}" A "q${n}_antes" "${PLANES}/q${n}_A_antes.txt"
  medir "Q${n}" B "q${n}_despues"
  guardar_plan "Q${n}" B "q${n}_despues" "${PLANES}/q${n}_B_solo_reescritura.txt"
done

log "Aplicando 03_optimizaciones.sql"
{ echo "-- Salida de 03_optimizaciones.sql (con tiempos de creación)"; echo;
  "${PSQL[@]}" -e <<< "\\timing on
\\i ${SQL_DIR}/03_optimizaciones.sql"; } > "${OUT}/03_optimizaciones.log" 2>&1

"${PSQL[@]}" <<< "
INSERT INTO medicion.indices
SELECT :'run', i.relname, t.relname, am.amname, pg_relation_size(i.oid)
FROM pg_index x
JOIN pg_class i ON i.oid = x.indexrelid
JOIN pg_class t ON t.oid = x.indrelid
JOIN pg_am am   ON am.oid = i.relam
WHERE i.relname LIKE 'ix\_%';
-- Referencia para el BRIN: cuánto ocuparía un B-Tree sobre la misma columna
CREATE INDEX tmp_btree_fecha ON citas (fecha_hora);
INSERT INTO medicion.indices
SELECT :'run', 'B-Tree equivalente a ix_citas_fecha_brin (solo comparación, se elimina)', 'citas', 'btree',
       pg_relation_size('tmp_btree_fecha');
DROP INDEX tmp_btree_fecha;" > /dev/null

log "Costo de inserción con índices"
"${PSQL[@]}" <<< "SELECT medicion.costo_insercion(:'run', 'con_indices');" > /dev/null

for n in 1 2 3; do
  log "Q${n}: escenario C (solo índices) y D (DESPUÉS)"
  medir "Q${n}" C "q${n}_antes"
  guardar_plan "Q${n}" C "q${n}_antes" "${PLANES}/q${n}_C_solo_indices.txt"
  medir "Q${n}" D "q${n}_despues"
  guardar_plan "Q${n}" D "q${n}_despues" "${PLANES}/q${n}_D_despues.txt"
done

log "Generando tiempos.csv y comparacion.md"
"${PSQL[@]}" <<< "\\copy (SELECT ejecucion, consulta, escenario, corrida, tiempo_ms, planificacion_ms, costo_estimado, filas, buffers_hit, buffers_read, operaciones, hash_resultado, medido_en FROM medicion.resultados WHERE ejecucion = '${RUN_ID}' ORDER BY consulta, escenario, corrida) TO '${OUT}/tiempos.csv' WITH (FORMAT csv, HEADER)"
"${PSQL[@]}" -f /runner/comparacion.sql > "${OUT}/comparacion.md"

log "Listo: evidencias en evidencias/${RUN_ID}"
