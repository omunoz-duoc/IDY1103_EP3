-- ============================================================
-- 05_explain_after.sql · consultas DESPUES (estructura sugerida por la pauta)
-- El texto de cada consulta vive en consultas/q<N>_despues.sql, así el
-- runner, este script y los demás usan exactamente el mismo SQL.
-- Uso (desde la carpeta del proyecto):
--   docker compose exec postgres psql -U dba -d salud360 -f /scripts/postgres/05_explain_after.sql
-- La medición automática (3 corridas, promedio) la hace runner/runner_pg.sh.
-- ============================================================
\timing on

\echo '--- Q1 (despues)'
\set q1 `grep -v '^\s*--' /scripts/postgres/consultas/q1_despues.sql`
EXPLAIN (ANALYZE, BUFFERS) :q1;

\echo '--- Q2 (despues)'
\set q2 `grep -v '^\s*--' /scripts/postgres/consultas/q2_despues.sql`
EXPLAIN (ANALYZE, BUFFERS) :q2;

\echo '--- Q3 (despues)'
\set q3 `grep -v '^\s*--' /scripts/postgres/consultas/q3_despues.sql`
EXPLAIN (ANALYZE, BUFFERS) :q3;
