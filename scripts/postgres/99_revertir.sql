-- ============================================================
-- 99_revertir.sql · vuelve al estado ANTES (sin los índices de la EP2)
-- ============================================================
DROP INDEX IF EXISTS ix_citas_disponibles;
DROP INDEX IF EXISTS ix_citas_fecha_brin;
DROP INDEX IF EXISTS ix_pacientes_nombre_trgm;
DROP INDEX IF EXISTS ix_citas_paciente_fecha;
ANALYZE citas;
ANALYZE pacientes;
