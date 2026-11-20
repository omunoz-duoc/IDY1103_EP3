-- Q3 ANTES · Búsqueda de paciente por nombre y sus próximas citas
-- Negocio: en cada llamada o llegada al mesón se busca al paciente por parte
-- de su nombre y se revisan sus horas futuras.
SELECT p.paciente_id, p.rut, p.nombre_completo, p.prevision,
       c.cita_id, c.fecha_hora, c.estado, s.nombre AS sede
FROM pacientes p
LEFT JOIN citas c ON c.paciente_id = p.paciente_id
                 AND c.fecha_hora >= TIMESTAMP '2026-11-02'
LEFT JOIN sedes s ON s.sede_id = c.sede_id
WHERE UPPER(p.nombre_completo) LIKE '%ROJAS MUÑOZ%'
ORDER BY p.nombre_completo, p.paciente_id, c.fecha_hora
