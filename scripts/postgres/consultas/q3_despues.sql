-- Q3 DESPUÉS · Búsqueda de paciente por nombre y sus próximas citas
-- Reescritura: ILIKE sobre la columna sin envolverla en UPPER(), para que el
-- índice de trigramas pueda usarse; se filtra primero a los pacientes
-- encontrados y luego se buscan sus citas futuras.
-- Apoyo: índice GIN (pg_trgm) ix_pacientes_nombre_trgm y B-Tree
-- ix_citas_paciente_fecha sobre la FK citas.paciente_id.
WITH encontrados AS (
  SELECT paciente_id, rut, nombre_completo, prevision
  FROM pacientes
  WHERE nombre_completo ILIKE '%rojas muñoz%'
)
SELECT p.paciente_id, p.rut, p.nombre_completo, p.prevision,
       c.cita_id, c.fecha_hora, c.estado, s.nombre AS sede
FROM encontrados p
LEFT JOIN citas c ON c.paciente_id = p.paciente_id
                 AND c.fecha_hora >= TIMESTAMP '2026-11-02'
LEFT JOIN sedes s ON s.sede_id = c.sede_id
ORDER BY p.nombre_completo, p.paciente_id, c.fecha_hora
