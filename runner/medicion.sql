-- ============================================================
-- runner/medicion.sql · funciones de medición (esquema "medicion")
-- Las usa runner_pg.sh. No forman parte del modelo del negocio.
-- ============================================================
CREATE SCHEMA IF NOT EXISTS medicion;

CREATE TABLE IF NOT EXISTS medicion.resultados (
  id                 SERIAL PRIMARY KEY,
  ejecucion          TEXT NOT NULL,      -- carpeta de evidencias (RUN_ID)
  consulta           TEXT NOT NULL,      -- Q1, Q2, Q3
  escenario          TEXT NOT NULL,      -- A..D (ver runner_pg.sh)
  corrida            INT  NOT NULL,      -- 1..3
  tiempo_ms          NUMERIC,            -- Execution Time de EXPLAIN ANALYZE
  planificacion_ms   NUMERIC,            -- Planning Time
  costo_estimado     NUMERIC,            -- Total Cost del nodo raíz
  filas              BIGINT,
  buffers_hit        BIGINT,             -- páginas leídas desde shared_buffers
  buffers_read       BIGINT,             -- páginas leídas fuera de shared_buffers
  operaciones        TEXT,               -- nodos del plan (Seq Scan citas, Index Scan ...)
  hash_resultado     TEXT,               -- md5 del resultado, para comprobar equivalencia
  plan               JSON,
  medido_en          TIMESTAMPTZ DEFAULT clock_timestamp()
);

CREATE TABLE IF NOT EXISTS medicion.escrituras (
  ejecucion  TEXT, escenario TEXT, corrida INT, filas INT, tiempo_ms NUMERIC
);

CREATE TABLE IF NOT EXISTS medicion.indices (
  ejecucion TEXT, indice TEXT, tabla TEXT, tipo TEXT, bytes BIGINT
);

-- Lista legible de los nodos del plan: "Seq Scan (citas)", "Index Scan (ix_...)"
CREATE OR REPLACE FUNCTION medicion.operaciones(p JSON) RETURNS TEXT AS $$
  -- Recorre el plan de arriba hacia abajo y deja cada operación una sola vez
  SELECT string_agg(op, ', ' ORDER BY orden)
  FROM (
    SELECT op, min(orden) AS orden
    FROM (
      SELECT (n->>'Node Type') ||
             COALESCE(' (' || COALESCE(n->>'Index Name', n->>'Relation Name') || ')', '') AS op,
             orden
      FROM jsonb_path_query(p::jsonb, 'strict $.**') WITH ORDINALITY AS t(n, orden)
      WHERE jsonb_typeof(n) = 'object' AND n ? 'Node Type'
        AND (n->>'Node Type') IN ('Seq Scan','Index Scan','Index Only Scan','Bitmap Index Scan',
                                  'Bitmap Heap Scan','Sort','Hash Join','Nested Loop','Merge Join',
                                  'HashAggregate','GroupAggregate','Aggregate','Incremental Sort')
    ) x
    GROUP BY op
  ) y;
$$ LANGUAGE sql;

-- Mide una consulta: 1 ejecución de calentamiento + p_n ejecuciones con
-- EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON). Guarda cada corrida.
CREATE OR REPLACE FUNCTION medicion.medir(p_ejec TEXT, p_consulta TEXT, p_escenario TEXT,
                                          p_sql TEXT, p_n INT DEFAULT 3) RETURNS VOID AS $$
DECLARE
  j JSON; h TEXT; i INT;
BEGIN
  -- Calentamiento: deja las páginas en caché igual para todos los escenarios.
  EXECUTE p_sql;

  -- Huella del resultado (mismas filas => mismo md5).
  EXECUTE format(E'SELECT md5(COALESCE(string_agg(t::text, %L ORDER BY t::text), %L)) FROM (%s\n) t',
                 '|', '', p_sql) INTO h;

  FOR i IN 1..p_n LOOP
    EXECUTE 'EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) ' || p_sql INTO j;
    INSERT INTO medicion.resultados (ejecucion, consulta, escenario, corrida, tiempo_ms, planificacion_ms,
                                     costo_estimado, filas, buffers_hit, buffers_read, operaciones,
                                     hash_resultado, plan)
    VALUES (p_ejec, p_consulta, p_escenario, i,
            (j->0->>'Execution Time')::NUMERIC,
            (j->0->>'Planning Time')::NUMERIC,
            (j->0->'Plan'->>'Total Cost')::NUMERIC,
            (j->0->'Plan'->>'Actual Rows')::NUMERIC::BIGINT,
            (j->0->'Plan'->>'Shared Hit Blocks')::BIGINT,
            (j->0->'Plan'->>'Shared Read Blocks')::BIGINT,
            medicion.operaciones(j),
            h, j);
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Costo de escritura: inserta p_filas citas nuevas y deshace el cambio.
-- Sirve para evidenciar el efecto secundario de los índices en INSERT.
CREATE OR REPLACE FUNCTION medicion.costo_insercion(p_ejec TEXT, p_escenario TEXT,
                                                    p_filas INT DEFAULT 20000, p_n INT DEFAULT 3)
RETURNS VOID AS $$
DECLARE
  t0 TIMESTAMPTZ; ms NUMERIC; i INT;
BEGIN
  FOR i IN 1..p_n LOOP
    BEGIN
      t0 := clock_timestamp();
      INSERT INTO citas (paciente_id, profesional_id, sede_id, fecha_hora, estado, canal, reservada_en)
      SELECT CASE WHEN g % 2 = 0 THEN NULL ELSE 1 + g % 50000 END,
             1 + g % 400, 1 + g % 20,
             TIMESTAMP '2027-01-01' + g * INTERVAL '1 minute',
             CASE WHEN g % 2 = 0 THEN 'DISPONIBLE' ELSE 'AGENDADA' END,
             CASE WHEN g % 2 = 0 THEN NULL ELSE 'WEB' END,
             CASE WHEN g % 2 = 0 THEN NULL ELSE TIMESTAMP '2026-11-02' END
      FROM generate_series(1, p_filas) g;
      ms := extract(epoch FROM clock_timestamp() - t0) * 1000;
      RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'deshacer';
    EXCEPTION WHEN SQLSTATE 'P0001' THEN
      INSERT INTO medicion.escrituras VALUES (p_ejec, p_escenario, i, p_filas, round(ms, 2));
    END;
  END LOOP;
END;
$$ LANGUAGE plpgsql;
