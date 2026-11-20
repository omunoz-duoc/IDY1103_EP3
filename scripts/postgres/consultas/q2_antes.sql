-- Q2 ANTES · Inasistencias y anulaciones por sede (octubre 2026)
-- Negocio: el analista de operaciones revisa qué sedes pierden más horas
-- (pacientes que no llegan o anulan). Reporte mensual y tablero.
SELECT t.*,
       round(100.0 * (t.inasistencias + t.anulaciones) / NULLIF(t.citas_tomadas, 0), 1) AS pct_horas_perdidas
FROM (
  SELECT s.nombre AS sede, s.region,
         (SELECT COUNT(*) FROM citas c
           WHERE c.sede_id = s.sede_id
             AND c.fecha_hora >= TIMESTAMP '2026-10-01' AND c.fecha_hora < TIMESTAMP '2026-11-01'
             AND c.estado <> 'DISPONIBLE')                     AS citas_tomadas,
         (SELECT COUNT(*) FROM citas c
           WHERE c.sede_id = s.sede_id
             AND c.fecha_hora >= TIMESTAMP '2026-10-01' AND c.fecha_hora < TIMESTAMP '2026-11-01'
             AND c.estado = 'NO_ASISTE')                       AS inasistencias,
         (SELECT COUNT(*) FROM citas c
           WHERE c.sede_id = s.sede_id
             AND c.fecha_hora >= TIMESTAMP '2026-10-01' AND c.fecha_hora < TIMESTAMP '2026-11-01'
             AND c.estado = 'ANULADA')                         AS anulaciones
  FROM sedes s
) t
ORDER BY pct_horas_perdidas DESC, sede
