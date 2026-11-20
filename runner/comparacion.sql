-- Genera comparacion.md a partir de medicion.resultados (lo llama runner_pg.sh)
-- Escenarios: A = consulta original sin índices (ANTES)
--             B = consulta reescrita sin índices (aporte de la reescritura)
--             C = consulta original con índices  (aporte de los índices)
--             D = consulta reescrita con índices (DESPUÉS)
\pset format unaligned
\pset tuples_only on

CREATE TEMP VIEW r AS
SELECT consulta, escenario,
       round(avg(tiempo_ms), 2)        AS prom,
       round(min(tiempo_ms), 2)        AS minimo,
       round(max(tiempo_ms), 2)        AS maximo,
       round(avg(planificacion_ms), 2) AS plan_ms,
       max(costo_estimado)             AS costo,
       max(filas)                      AS filas,
       max(buffers_hit + buffers_read) AS buffers,
       max(operaciones)                AS ops,
       max(hash_resultado)             AS hash
FROM medicion.resultados
WHERE ejecucion = :'run'
GROUP BY consulta, escenario;

SELECT '# Comparación ANTES vs DESPUÉS (PostgreSQL)';
SELECT '';
SELECT 'Ejecución `' || :'run' || '`. Tiempos = "Execution Time" de `EXPLAIN (ANALYZE, BUFFERS)`, promedio de 3 corridas después de 1 de calentamiento. Buffers = páginas de 8 KB leídas (hit + read). Detalle de cada corrida en `tiempos.csv`.';
SELECT '';
SELECT '## Resumen por consulta';
SELECT '';
SELECT '| Consulta | ANTES prom. ms (mín–máx) | DESPUÉS prom. ms (mín–máx) | Mejora | Costo estimado antes → después | Buffers antes → después | Filas | Mismo resultado |';
SELECT '| --- | --- | --- | --- | --- | --- | --- | --- |';
SELECT format('| %s | %s (%s–%s) | %s (%s–%s) | %s%% | %s → %s | %s → %s | %s | %s |',
              a.consulta, a.prom, a.minimo, a.maximo, d.prom, d.minimo, d.maximo,
              round(100 * (a.prom - d.prom) / NULLIF(a.prom, 0), 1),
              round(a.costo), round(d.costo), a.buffers, d.buffers, d.filas,
              CASE WHEN a.hash = d.hash THEN 'sí' ELSE 'NO' END)
FROM r a JOIN r d ON d.consulta = a.consulta AND d.escenario = 'D'
WHERE a.escenario = 'A' ORDER BY a.consulta;
SELECT '';
SELECT '## Cambio en el plan';
SELECT '';
SELECT '| Consulta | Operaciones ANTES | Operaciones DESPUÉS |';
SELECT '| --- | --- | --- |';
SELECT format('| %s | %s | %s |', a.consulta, a.ops, d.ops)
FROM r a JOIN r d ON d.consulta = a.consulta AND d.escenario = 'D'
WHERE a.escenario = 'A' ORDER BY a.consulta;
SELECT '';
SELECT '## Aporte de cada optimización (tiempo promedio, ms)';
SELECT '';
SELECT 'Para justificar cada ajuste por separado se miden las 4 combinaciones.';
SELECT '';
SELECT '| Consulta | A: original sin índices (ANTES) | B: solo reescritura | C: solo índices | D: reescritura + índices (DESPUÉS) |';
SELECT '| --- | --- | --- | --- | --- |';
SELECT format('| %s | %s | %s | %s | %s |', consulta,
              max(prom) FILTER (WHERE escenario = 'A'), max(prom) FILTER (WHERE escenario = 'B'),
              max(prom) FILTER (WHERE escenario = 'C'), max(prom) FILTER (WHERE escenario = 'D'))
FROM r GROUP BY consulta ORDER BY consulta;
SELECT '';
SELECT '## Costo de los índices';
SELECT '';
SELECT '| Índice | Tabla | Tipo | Tamaño |';
SELECT '| --- | --- | --- | --- |';
SELECT format('| %s | %s | %s | %s |', indice, tabla, tipo, pg_size_pretty(bytes))
FROM medicion.indices WHERE ejecucion = :'run' ORDER BY tabla, indice;
SELECT '';
SELECT 'Inserción de 20.000 citas (promedio de 3, cambios deshechos): '
       || string_agg(format('%s = %s ms', CASE escenario WHEN 'sin_indices' THEN 'sin índices' ELSE 'con índices' END,
                            round(avg_ms, 1)), ', ' ORDER BY escenario DESC) || '.'
FROM (SELECT escenario, avg(tiempo_ms) AS avg_ms FROM medicion.escrituras
      WHERE ejecucion = :'run' GROUP BY escenario) e;
