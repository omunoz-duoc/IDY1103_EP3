-- Q2 DESPUÉS · Inasistencias y anulaciones por sede (octubre 2026)
-- Reescritura: una sola pasada sobre citas con GROUP BY y COUNT(*) FILTER,
-- en vez de 3 subconsultas correlacionadas por cada sede (60 recorridos).
-- Apoyo: índice BRIN ix_citas_fecha_brin sobre fecha_hora.
WITH resumen AS (
  SELECT c.sede_id,
         COUNT(*) FILTER (WHERE c.estado <> 'DISPONIBLE') AS citas_tomadas,
         COUNT(*) FILTER (WHERE c.estado = 'NO_ASISTE')   AS inasistencias,
         COUNT(*) FILTER (WHERE c.estado = 'ANULADA')     AS anulaciones
  FROM citas c
  WHERE c.fecha_hora >= TIMESTAMP '2026-10-01' AND c.fecha_hora < TIMESTAMP '2026-11-01'
  GROUP BY c.sede_id
)
SELECT s.nombre AS sede, s.region,
       COALESCE(r.citas_tomadas, 0) AS citas_tomadas,
       COALESCE(r.inasistencias, 0) AS inasistencias,
       COALESCE(r.anulaciones, 0)   AS anulaciones,
       round(100.0 * (r.inasistencias + r.anulaciones) / NULLIF(r.citas_tomadas, 0), 1) AS pct_horas_perdidas
FROM sedes s
LEFT JOIN resumen r ON r.sede_id = s.sede_id
ORDER BY pct_horas_perdidas DESC, sede
