-- ============================================================
-- 03_optimizaciones.sql · índices y estadísticas
-- Cada índice responde a una consulta crítica. Se revierte con 99_revertir.sql.
-- ============================================================

-- Q1 · Disponibilidad de horas
-- B-Tree compuesto y PARCIAL: solo indexa los bloques DISPONIBLE (~19% de la
-- tabla), ordenados por sede y fecha. Así el motor va directo al rango
-- sede + semana, ya ordenado por fecha (evita el Sort), y con INCLUDE trae
-- profesional_id sin visitar la tabla para descartar filas.
CREATE INDEX ix_citas_disponibles
    ON citas (sede_id, fecha_hora)
    INCLUDE (profesional_id)
    WHERE estado = 'DISPONIBLE';

-- Q2 · Inasistencias y anulaciones por sede
-- BRIN sobre fecha_hora: guarda el mínimo y máximo de fecha por cada bloque
-- de 128 páginas. Sirve porque las citas se insertan en orden cronológico
-- (correlación física ~1). Ocupa una fracción de lo que ocupa un B-Tree.
CREATE INDEX ix_citas_fecha_brin
    ON citas USING brin (fecha_hora);

-- Q3 · Búsqueda de paciente por nombre
-- GIN con trigramas (pg_trgm): permite usar índice en LIKE/ILIKE '%texto%',
-- que un B-Tree no puede resolver porque el patrón empieza con comodín.
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX ix_pacientes_nombre_trgm
    ON pacientes USING gin (nombre_completo gin_trgm_ops);

-- B-Tree compuesto sobre la FK citas.paciente_id (+ fecha): resuelve el join
-- paciente -> citas futuras sin recorrer las 500.000 citas.
CREATE INDEX ix_citas_paciente_fecha
    ON citas (paciente_id, fecha_hora);

-- Estadísticas actualizadas para que el planificador conozca los índices nuevos.
ANALYZE citas;
ANALYZE pacientes;
