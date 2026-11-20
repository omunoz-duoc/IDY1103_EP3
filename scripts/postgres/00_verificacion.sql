-- ============================================================
-- 00_verificacion.sql · verificación de carga (punto 1.3 de la pauta)
-- pacientes, citas y cita_prestaciones equivalen a
-- ep2_customers, ep2_orders y ep2_order_items de la referencia.
-- ============================================================
SELECT 'pacientes (ep2_customers)'           AS tabla, COUNT(*) AS filas FROM pacientes
UNION ALL SELECT 'citas (ep2_orders)',                   COUNT(*) FROM citas
UNION ALL SELECT 'cita_prestaciones (ep2_order_items)', COUNT(*) FROM cita_prestaciones
UNION ALL SELECT 'prestaciones (ep2_products)',          COUNT(*) FROM prestaciones
UNION ALL SELECT 'pagos (ep2_payments)',                 COUNT(*) FROM pagos
UNION ALL SELECT 'sedes (ep2_stores)',                   COUNT(*) FROM sedes
UNION ALL SELECT 'profesionales',                        COUNT(*) FROM profesionales
UNION ALL SELECT 'especialidades',                       COUNT(*) FROM especialidades;

-- Distribución de estados de la agenda
SELECT estado, COUNT(*) AS filas,
       round(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM citas GROUP BY estado ORDER BY filas DESC;

-- Índices existentes antes de optimizar (solo PK, igual que la referencia)
SELECT tablename AS tabla, indexname AS indice
FROM pg_indexes WHERE schemaname = 'public' ORDER BY 1, 2;
