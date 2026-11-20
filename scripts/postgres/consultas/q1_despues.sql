-- Q1 DESPUÉS · Disponibilidad de horas
-- Reescritura: rango directo sobre fecha_hora (sargable), filtro por sede_id
-- resuelto antes del join (sin unir la tabla sedes completa).
-- Apoyo: índice B-Tree compuesto y parcial ix_citas_disponibles.
SELECT c.cita_id, c.fecha_hora, p.nombre_completo AS profesional, e.nombre AS especialidad
FROM citas c
JOIN profesionales p  ON p.profesional_id  = c.profesional_id
JOIN especialidades e ON e.especialidad_id = p.especialidad_id
WHERE c.sede_id = (SELECT sede_id FROM sedes WHERE nombre = 'Sede Santiago Centro')
  AND e.nombre = 'Cardiología'
  AND c.estado = 'DISPONIBLE'
  AND c.fecha_hora >= TIMESTAMP '2026-11-02'
  AND c.fecha_hora <  TIMESTAMP '2026-11-09'
ORDER BY c.fecha_hora, c.cita_id
