# Comparación ANTES vs DESPUÉS (PostgreSQL)

Ejecución `2026-11-20_231137`. Tiempos = "Execution Time" de `EXPLAIN (ANALYZE, BUFFERS)`, promedio de 3 corridas después de 1 de calentamiento. Buffers = páginas de 8 KB leídas (hit + read). Detalle de cada corrida en `tiempos.csv`.

## Resumen por consulta

| Consulta | ANTES prom. ms (mín–máx) | DESPUÉS prom. ms (mín–máx) | Mejora | Costo estimado antes → después | Buffers antes → después | Filas | Mismo resultado |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Q1 | 36.39 (35.89–37.02) | 0.20 (0.20–0.20) | 99.5% | 18998 → 342 | 6368 → 93 | 40 | sí |
| Q2 | 2475.48 (2262.49–2609.55) | 9.34 (9.20–9.43) | 99.6% | 2092986 → 8301 | 763441 → 1095 | 20 | sí |
| Q3 | 37.18 (37.00–37.52) | 0.62 (0.60–0.65) | 98.3% | 15034 → 153 | 7183 → 158 | 22 | sí |

## Cambio en el plan

| Consulta | Operaciones ANTES | Operaciones DESPUÉS |
| --- | --- | --- |
| Q1 | Sort, Nested Loop, Seq Scan (especialidades), Seq Scan (profesionales), Seq Scan (sedes), Seq Scan (citas) | Sort, Seq Scan (sedes), Hash Join, Bitmap Heap Scan (citas), Bitmap Index Scan (ix_citas_disponibles), Seq Scan (profesionales), Seq Scan (especialidades) |
| Q2 | Sort, Seq Scan (sedes), Aggregate, Seq Scan (citas) | Sort, Hash Join, Seq Scan (sedes), Aggregate, Bitmap Heap Scan (citas), Bitmap Index Scan (ix_citas_fecha_brin) |
| Q3 | Sort, Nested Loop, Hash Join, Seq Scan (citas), Seq Scan (pacientes), Index Scan (sedes_pkey) | Sort, Nested Loop, Bitmap Heap Scan (pacientes), Bitmap Index Scan (ix_pacientes_nombre_trgm), Index Scan (ix_citas_paciente_fecha), Index Scan (sedes_pkey) |

## Aporte de cada optimización (tiempo promedio, ms)

Para justificar cada ajuste por separado se miden las 4 combinaciones.

| Consulta | A: original sin índices (ANTES) | B: solo reescritura | C: solo índices | D: reescritura + índices (DESPUÉS) |
| --- | --- | --- | --- | --- |
| Q1 | 36.39 | 22.80 | 3.90 | 0.20 |
| Q2 | 2475.48 | 22.90 | 384.83 | 9.34 |
| Q3 | 37.18 | 57.03 | 16.38 | 0.62 |

## Costo de los índices

| Índice | Tabla | Tipo | Tamaño |
| --- | --- | --- | --- |
| B-Tree equivalente a ix_citas_fecha_brin (solo comparación, se elimina) | citas | btree | 3576 kB |
| ix_citas_disponibles | citas | btree | 3768 kB |
| ix_citas_fecha_brin | citas | brin | 24 kB |
| ix_citas_paciente_fecha | citas | btree | 13 MB |
| ix_pacientes_nombre_trgm | pacientes | gin | 2360 kB |

Inserción de 20.000 citas (promedio de 3, cambios deshechos): sin índices = 235.9 ms, con índices = 292.9 ms.

# Consulta extra en MongoDB

Tiempo = duración de `aggregate().toArray()` medida desde el cliente, promedio de 3 corridas después de 1 de calentamiento. Documentos y claves examinados salen de `explain("executionStats")`.

| Consulta | ANTES prom. ms (mín–máx) | DESPUÉS prom. ms (mín–máx) | Mejora | Docs examinados antes → después | Claves examinadas antes → después | Grupos | Mismo resultado |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Anulaciones por sede y motivo | 214.7 (186–234) | 11.0 (11–11) | 94.9% | 600000 → 4883 | 0 → 4883 | 140 | sí |

| Escenario | Prom. ms | Docs examinados | Claves examinadas | Etapas del plan |
| --- | --- | --- | --- | --- |
| A: original sin índice (ANTES) | 214.7 | 600000 | 0 | COLLSCAN → PROJECTION_DEFAULT → $addFields → $match → $group → $sort |
| B: solo reescritura | 185.7 | 600000 | 0 | COLLSCAN → GROUP → $sort |
| C: solo índice | 188.7 | 59924 | 59924 | IXSCAN (ix_eventos_tipo_ts) → FETCH → PROJECTION_DEFAULT → $addFields → $match → $group → $sort |
| D: reescritura + índice (DESPUÉS) | 11.0 | 4883 | 4883 | IXSCAN (ix_eventos_tipo_ts) → FETCH → GROUP → $sort |

Tamaño de índices en eventos_cita: _id_ = 6.0 MB, ix_eventos_tipo_ts = 6.8 MB.
