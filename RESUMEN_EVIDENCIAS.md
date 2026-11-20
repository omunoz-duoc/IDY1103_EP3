# Resumen de evidencias · EP2 Salud Integral 360

Las 3 consultas críticas de PostgreSQL y la consulta extra de MongoDB bajaron su tiempo entre 94,9% y 99,6%, devolviendo exactamente el mismo resultado. Cada una combina una reescritura con un tipo de índice distinto. Las cifras son de la ejecución de referencia `evidencias/2026-11-20_231137/`. En otro equipo los milisegundos cambian, pero los planes, los buffers y la tendencia deben repetirse.

| Consulta | Índice usado | ANTES | DESPUÉS | Mejora | Buffers o documentos leídos |
| --- | --- | --- | --- | --- | --- |
| Q1 Disponibilidad de horas | B-Tree compuesto y parcial | 36,39 ms | 0,20 ms | 99,5% | 6.368 → 93 páginas |
| Q2 Inasistencias por sede | BRIN | 2.475,48 ms | 9,34 ms | 99,6% | 763.441 → 1.095 páginas |
| Q3 Búsqueda de paciente | GIN (pg_trgm) + B-Tree en FK | 37,18 ms | 0,62 ms | 98,3% | 7.183 → 158 páginas |
| Extra (MongoDB) Motivos de anulación | Compuesto `{tipo, ts}` | 214,7 ms | 11,0 ms | 94,9% | 600.000 → 4.883 documentos |

Tiempos de PostgreSQL: "Execution Time" de `EXPLAIN (ANALYZE, BUFFERS)`, promedio de 3 corridas tras 1 de calentamiento. MongoDB: tiempo de `aggregate()` medido desde el cliente, con el mismo esquema de corridas. El detalle está en `comparacion.md` y `tiempos.csv`.

## Ambiente de la ejecución de referencia

PostgreSQL 18.7 y MongoDB 8.0.38, cada uno limitado a 2 CPU y 2 GB de RAM, sobre un Intel Xeon de 2,10 GHz con Linux. PostgreSQL usa `shared_buffers` de 512 MB, `work_mem` de 4 MB, JIT apagado y sin paralelismo. MongoDB usa 1 GB de caché WiredTiger. El volumen es de 500.000 citas, ~976.000 prestaciones por cita, 50.000 pacientes y 600.000 eventos en MongoDB (173 MB en PostgreSQL). El detalle completo está en `00_ambiente.md` y `00_ambiente_host.txt`.

## Q1 · Disponibilidad de horas

**Negocio.** El call center y la recepción buscan horas libres de Cardiología en la Sede Santiago Centro para la próxima semana. Es la consulta más frecuente del caso y la que más se resiente en hora punta.

**ANTES** (`planes/q1_A_antes.txt`): 36,39 ms, 6.368 páginas leídas. Causas de congestión:

1. **Filtro no sargable y lectura completa.** `DATE(c.fecha_hora) BETWEEN ...` aplica una función a la columna, así que ningún índice sobre `fecha_hora` podría usarse. El plan hace `Seq Scan on citas` y descarta 495.525 de 500.000 filas para quedarse con 4.475.
2. **Estimación errónea y filtro tardío.** Por la función, el planificador estima 530 filas cuando son 4.475, más de 8 veces menos. Además, la sede se filtra recién en el join con `sedes`, después de leer todas las citas de la semana de todas las sedes.

**Optimizaciones.**

- Reescritura: rango directo `fecha_hora >= '2026-11-02' AND fecha_hora < '2026-11-09'` y `sede_id` resuelto antes del join.
- Índice B-Tree compuesto y parcial `ix_citas_disponibles (sede_id, fecha_hora) INCLUDE (profesional_id) WHERE estado = 'DISPONIBLE'`. Es parcial porque la pantalla solo busca horas libres, que son el 19% de la tabla, así que el índice es más chico. El orden de columnas pone primero la igualdad (sede) y después el rango (fecha).

**DESPUÉS** (`planes/q1_D_despues.txt`): 0,20 ms y 93 páginas. El `Seq Scan` se reemplaza por `Bitmap Index Scan on ix_citas_disponibles`, que entrega directamente las 262 horas libres de esa sede y semana. Por separado, la reescritura sola lleva a 22,80 ms (sigue siendo un scan completo) y el índice solo a 3,90 ms (el índice se usa, pero la sede se sigue resolviendo tarde). Juntas suman el efecto completo.

## Q2 · Inasistencias y anulaciones por sede

**Negocio.** El analista de operaciones revisa cada mes qué sedes pierden más horas por pacientes que no llegan o anulan. Alimenta el tablero de gestión.

**ANTES** (`planes/q2_A_antes.txt`): 2.475,48 ms, 763.441 páginas leídas (unos 6 GB recorridos en memoria). Causas de congestión:

1. **Subconsultas correlacionadas.** Tres `SubPlan` por cada una de las 20 sedes: el plan muestra `loops=20` en cada una, es decir 60 ejecuciones.
2. **Lectura completa repetida.** Cada una de esas 60 ejecuciones hace `Seq Scan on citas` y descarta ~498.000 filas para contar ~1.575 del mes. La tabla completa se lee 60 veces.

**Optimizaciones.**

- Reescritura: una sola pasada con `GROUP BY sede_id` y `COUNT(*) FILTER (WHERE estado = ...)`, que cuenta los tres indicadores a la vez.
- Índice BRIN `ix_citas_fecha_brin (fecha_hora)`. Las citas se insertan en orden cronológico (correlación física 1,0), así que guardar solo el mínimo y el máximo de fecha por cada bloque de 128 páginas basta para saltar todo lo que no es octubre.

**DESPUÉS** (`planes/q2_D_despues.txt`): 9,34 ms y 1.095 páginas, con un único `Bitmap Heap Scan` guiado por el BRIN. La reescritura es la que más aporta (22,90 ms sola), porque elimina las 60 lecturas. El BRIN solo baja la consulta original a 384,83 ms, pero sigue repitiendo 60 recorridos. El BRIN ocupa **24 kB**, frente a **3.576 kB** de un B-Tree sobre la misma columna, unas 150 veces menos. Es la opción adecuada para columnas de fecha en tablas que crecen en orden.

## Q3 · Búsqueda de paciente y sus próximas citas

**Negocio.** En cada llamada o llegada al mesón se busca al paciente por parte de su nombre ("rojas muñoz") y se revisan sus horas futuras.

**ANTES** (`planes/q3_A_antes.txt`): 37,18 ms y 7.183 páginas. Causas de congestión:

1. **Búsqueda con comodín inicial.** `UPPER(nombre_completo) LIKE '%ROJAS MUÑOZ%'` obliga a `Seq Scan on pacientes` (50.000 filas para encontrar 19). Un B-Tree no puede resolver un patrón que empieza con `%`.
2. **FK sin índice.** `citas.paciente_id` no tiene índice, así que para unir 19 pacientes con sus citas el motor hace `Seq Scan on citas` y arma un `Hash Right Join` con 70.487 citas futuras de todos los pacientes.

**Optimizaciones.**

- Reescritura: `nombre_completo ILIKE '%rojas muñoz%'`, sin envolver la columna en `UPPER()`, para que el índice de trigramas sea utilizable, y filtrar primero a los pacientes encontrados.
- Índice GIN con `pg_trgm` sobre `nombre_completo`, que indexa grupos de 3 letras y sí resuelve `LIKE/ILIKE '%...%'`. Es el equivalente en PostgreSQL al índice Full-Text del material.
- Índice B-Tree `ix_citas_paciente_fecha (paciente_id, fecha_hora)` sobre la FK, que entrega solo las citas futuras de cada paciente.

**DESPUÉS** (`planes/q3_D_despues.txt`): 0,62 ms y 158 páginas, con `Bitmap Index Scan on ix_pacientes_nombre_trgm` seguido de `Index Scan using ix_citas_paciente_fecha`. Un hallazgo para defender: **la reescritura sola empeora el tiempo** (57,03 ms contra 37,18 ms), porque sin índice `ILIKE` es más caro de evaluar que `UPPER() LIKE`. Su valor está en habilitar el índice GIN. Es un buen ejemplo de que una optimización se justifica por el conjunto y no por separado.

## Consulta extra · MongoDB: motivos de anulación por sede

**Negocio.** El analista de operaciones y el supervisor del call center revisan a diario por qué se anulan horas en cada sede en los últimos 30 días.

**ANTES** (`planes/mongo_A_antes.json`): 214,7 ms. Plan `COLLSCAN → $addFields → $match → $group`. Se examinan los 600.000 documentos porque el filtro de fecha se aplica sobre `dia`, un campo calculado con `$addFields` que no puede estar en ningún índice.

**Optimizaciones.**

- Reescritura: `$match` directo sobre los campos guardados, `tipo` y `ts`, como primera etapa.
- Índice compuesto `ix_eventos_tipo_ts {tipo: 1, ts: 1}`, según la regla igualdad, orden, rango (ESR): primero la igualdad, después el rango.

**DESPUÉS** (`planes/mongo_D_despues.json`): 11,0 ms, `IXSCAN → FETCH → GROUP`, con 4.883 documentos examinados, exactamente los que se agrupan. El índice solo (escenario C) aprovecha el prefijo `tipo`, pero igual lee 59.924 anulaciones de todo el año (188,7 ms). Recién con la reescritura el rango de fecha entra al índice.

## Costos y efectos secundarios

- **Espacio.** Los 4 índices de PostgreSQL suman unos 19 MB (13 MB es el B-Tree de la FK). El índice de MongoDB ocupa 6,8 MB.
- **Escrituras.** Insertar 20.000 citas pasa de 235,9 ms sin índices a 292,9 ms con índices, un 24% más lento, porque cada INSERT mantiene 3 índices adicionales sobre `citas`. En una red clínica la agenda se consulta mucho más seguido de lo que se crean bloques nuevos, así que el costo es razonable, pero habría que vigilarlo en cargas masivas de agenda.
- **Dependencias del diseño.** El BRIN depende de que las citas se sigan insertando en orden de fecha: si se cargan agendas desordenadas, pierde efectividad. El índice parcial solo sirve a consultas que filtran `estado = 'DISPONIBLE'`.

## Limitaciones del entorno

- Los datos son sintéticos y uniformes. En producción la distribución real (sedes más grandes, horas punta) cambia la selectividad.
- Paralelismo y JIT están apagados para que los planes sean estables entre equipos. En producción, con paralelismo, los tiempos ANTES serían menores, pero las lecturas totales serían las mismas.
- Las mediciones se hacen con caché caliente. Con caché fría, la diferencia a favor de los índices sería mayor, porque las lecturas a disco pesan más.
- Los eventos de MongoDB son independientes de las citas de PostgreSQL (las referencias por `cita_id` y `paciente_id` son aleatorias).

## Mejoras futuras

1. Activar `pg_stat_statements` para elegir consultas por tiempo total acumulado (frecuencia × costo) en vez de por percepción.
2. Índice Hash sobre `pacientes.rut` para la búsqueda exacta por RUT, el otro patrón frecuente del mesón.
3. Particionar `citas` por mes cuando supere algunos millones de filas. El reporte de Q2 leería una sola partición y el BRIN dejaría de ser necesario.
4. Revisar con `pg_stat_user_indexes` que los índices nuevos se usen en producción y eliminar los que no.
