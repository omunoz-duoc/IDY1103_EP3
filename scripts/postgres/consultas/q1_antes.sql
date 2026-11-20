-- Q1 ANTES · Disponibilidad de horas
-- Negocio: el call center y la recepción buscan horas libres de una especialidad
-- en una sede para la próxima semana. Se ejecuta cientos de veces al día.
SELECT c.cita_id, c.fecha_hora, p.nombre_completo AS profesional, e.nombre AS especialidad
FROM citas c
JOIN profesionales p   ON p.profesional_id  = c.profesional_id
JOIN especialidades e  ON e.especialidad_id = p.especialidad_id
JOIN sedes s           ON s.sede_id         = c.sede_id
WHERE s.nombre = 'Sede Santiago Centro'
  AND e.nombre = 'Cardiología'
  AND c.estado = 'DISPONIBLE'
  AND DATE(c.fecha_hora) BETWEEN DATE '2026-11-02' AND DATE '2026-11-08'
ORDER BY c.fecha_hora, c.cita_id
