-- ============================================================
-- 01_consultas_before.sql · consultas ANTES (estructura sugerida por la pauta)
-- El texto de cada consulta vive en consultas/q<N>_antes.sql, así el
-- runner, este script y los demás usan exactamente el mismo SQL.
-- Uso (desde la carpeta del proyecto):
--   docker compose exec postgres psql -U dba -d salud360 -f /scripts/postgres/01_consultas_before.sql
-- La medición automática (3 corridas, promedio) la hace runner/runner_pg.sh.
-- ============================================================
\timing on

\echo '--- Q1 (antes)'
\set q1 `grep -v '^\s*--' /scripts/postgres/consultas/q1_antes.sql`
:q1;

\echo '--- Q2 (antes)'
\set q2 `grep -v '^\s*--' /scripts/postgres/consultas/q2_antes.sql`
:q2;

\echo '--- Q3 (antes)'
\set q3 `grep -v '^\s*--' /scripts/postgres/consultas/q3_antes.sql`
:q3;
