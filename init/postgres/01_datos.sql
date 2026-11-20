-- ============================================================
-- Salud Integral 360 · EP2 IDY1103
-- 01_datos.sql: carga de datos sintéticos y reproducibles
--
-- * setseed() fija la semilla: todos obtienen exactamente los mismos datos.
-- * Fecha de referencia ("hoy" del caso): 2026-11-02 (lunes).
--   La agenda cubre 365 días hacia atrás y 60 días hacia adelante.
-- * Las citas se insertan en orden cronológico, como cuando una agenda
--   se abre por períodos (esto es lo que aprovecha el índice BRIN).
--
-- Volúmenes aproximados:
--   sedes 20 · especialidades 12 · profesionales 400 · pacientes 50.000
--   prestaciones 2.000 · citas 500.000 · cita_prestaciones ~1.000.000
--   pagos ~280.000
-- ============================================================

SET max_parallel_workers_per_gather = 0;   -- generación determinista
SELECT setseed(0.360);

-- ---------- Catálogos ----------
INSERT INTO sedes (nombre, region) VALUES
  ('Sede Santiago Centro','RM'), ('Sede Providencia','RM'), ('Sede Maipú','RM'),
  ('Sede La Florida','RM'), ('Sede Puente Alto','RM'), ('Sede Ñuñoa','RM'),
  ('Sede Las Condes','RM'), ('Sede San Bernardo','RM'),
  ('Sede Talca','Maule'), ('Sede Curicó','Maule'), ('Sede Linares','Maule'), ('Sede Constitución','Maule'),
  ('Sede Concepción','Biobío'), ('Sede Talcahuano','Biobío'), ('Sede Los Ángeles','Biobío'), ('Sede Coronel','Biobío'),
  ('Sede Viña del Mar','Valparaíso'), ('Sede Valparaíso','Valparaíso'), ('Sede Quilpué','Valparaíso'), ('Sede San Antonio','Valparaíso');

INSERT INTO especialidades (nombre) VALUES
  ('Medicina General'), ('Pediatría'), ('Cardiología'), ('Traumatología'), ('Ginecología'),
  ('Dermatología'), ('Oftalmología'), ('Otorrinolaringología'), ('Neurología'),
  ('Psiquiatría'), ('Kinesiología'), ('Nutrición');

-- Listas de nombres para pacientes y profesionales
CREATE TEMP TABLE tmp_nombres (n TEXT[]);
INSERT INTO tmp_nombres VALUES (ARRAY[
  'María','José','Juan','Ana','Luis','Carmen','Pedro','Francisca','Diego','Valentina',
  'Camila','Javiera','Matías','Benjamín','Sofía','Martina','Tomás','Ignacio','Fernanda','Catalina',
  'Felipe','Constanza','Sebastián','Daniela','Cristóbal','Antonia','Vicente','Isidora','Joaquín','Florencia',
  'Rodrigo','Paula','Andrés','Carolina','Gabriel','Macarena','Nicolás','Bárbara','Pablo','Claudia']);
CREATE TEMP TABLE tmp_apellidos (a TEXT[]);
INSERT INTO tmp_apellidos VALUES (ARRAY[
  'González','Muñoz','Rojas','Díaz','Pérez','Soto','Contreras','Silva','Martínez','Sepúlveda',
  'Morales','Rodríguez','López','Fuentes','Hernández','Torres','Araya','Flores','Espinoza','Valenzuela',
  'Castillo','Tapia','Reyes','Gutiérrez','Castro','Pizarro','Álvarez','Vásquez','Sánchez','Fernández',
  'Ramírez','Carrasco','Gómez','Cortés','Herrera','Núñez','Jara','Vergara','Rivera','Figueroa',
  'Riquelme','García','Miranda','Bravo','Vera','Molina','Vega','Campos','Sandoval','Orellana',
  'Cárdenas','Olivares','Alarcón','Gallardo','Ortiz','Garrido','Salazar','Guzmán','Henríquez','Saavedra']);

-- Dígito verificador de RUT (módulo 11)
CREATE FUNCTION pg_temp.dv(num BIGINT) RETURNS TEXT AS $$
  SELECT CASE r WHEN 11 THEN '0' WHEN 10 THEN 'K' ELSE r::TEXT END
  FROM (SELECT 11 - (SUM(d::INT * (2 + (i - 1) % 6)) % 11) AS r
        FROM unnest(string_to_array(reverse(num::TEXT), NULL)) WITH ORDINALITY AS t(d, i)) s;
$$ LANGUAGE sql IMMUTABLE;

INSERT INTO profesionales (nombre_completo, especialidad_id, sede_id, activo)
SELECT 'Dr(a). ' || n[1 + floor(random()*40)::INT] || ' ' || a[1 + floor(random()*60)::INT],
       1 + floor(random()*12)::INT,
       1 + floor(random()*20)::INT,
       random() > 0.03
FROM generate_series(1, 400), tmp_nombres, tmp_apellidos;

INSERT INTO pacientes (rut, nombre_completo, email, fecha_nacimiento, comuna, prevision, creado_en)
SELECT (5000000 + gs * 97)::TEXT || '-' || pg_temp.dv(5000000 + gs * 97),
       n[1 + floor(random()*40)::INT] || ' ' || a[1 + floor(random()*60)::INT] || ' ' || a[1 + floor(random()*60)::INT],
       'paciente' || gs || '@correo.cl',
       DATE '1940-01-01' + floor(random() * 30000)::INT,
       (ARRAY['Santiago','Providencia','Maipú','La Florida','Puente Alto','Ñuñoa','Talca','Curicó',
              'Concepción','Talcahuano','Los Ángeles','Viña del Mar','Valparaíso','Quilpué'])[1 + floor(random()*14)::INT],
       CASE WHEN random() < 0.75 THEN 'FONASA' WHEN random() < 0.8 THEN 'ISAPRE' ELSE 'PARTICULAR' END,
       TIMESTAMP '2026-11-02' - random() * INTERVAL '1500 days'
FROM generate_series(1, 50000) gs, tmp_nombres, tmp_apellidos;

INSERT INTO prestaciones (codigo, nombre, tipo, valor, activa)
SELECT 'PR' || lpad(gs::TEXT, 5, '0'),
       t || ' ' || gs,
       t,
       round((random() * 150000 + 3000)::NUMERIC, 0),
       random() > 0.05
FROM (SELECT gs, (ARRAY['Consulta','Examen','Procedimiento','Imagenología','Laboratorio'])[1 + floor(random()*5)::INT] AS t
      FROM generate_series(1, 2000) gs) x;

-- ---------- Agenda / citas (orden cronológico) ----------
CREATE TEMP TABLE tmp_citas AS
SELECT row_number() OVER (ORDER BY fh, prof) AS cita_id, *
FROM (
  SELECT fh, prof, pac, r2,
         CASE WHEN fh < TIMESTAMP '2026-11-02' THEN
                CASE WHEN r < 0.13 THEN 'DISPONIBLE'      -- hora que nunca se tomó
                     WHEN r < 0.25 THEN 'ANULADA'
                     WHEN r < 0.35 THEN 'NO_ASISTE'
                     ELSE 'ATENDIDA' END
              ELSE
                CASE WHEN r < 0.55 THEN 'DISPONIBLE'
                     WHEN r < 0.80 THEN 'AGENDADA'
                     WHEN r < 0.92 THEN 'CONFIRMADA'
                     ELSE 'ANULADA' END
         END AS estado
  FROM (
    SELECT TIMESTAMP '2025-11-02'
             + floor(random() * 425)::INT * INTERVAL '1 day'
             + (480 + 20 * floor(random() * 30))::INT * INTERVAL '1 minute' AS fh,   -- 08:00 a 17:40
           1 + floor(random() * 400)::INT    AS prof,
           1 + floor(random() * 50000)::BIGINT AS pac,
           random() AS r,
           random() AS r2
    FROM generate_series(1, 500000)
  ) a
) b;

-- Prestaciones de cada cita atendida (1 a 6 por cita)
CREATE TEMP TABLE tmp_items AS
SELECT c.cita_id,
       1 + floor(random() * 2000)::INT AS prestacion_id,
       1 + floor(random() * 3)::INT    AS cantidad,
       round((random() * 150000 + 3000)::NUMERIC, 0) AS valor_unitario
FROM tmp_citas c
CROSS JOIN LATERAL generate_series(1, 1 + floor(random() * 6)::INT + (c.cita_id * 0)::INT)
WHERE c.estado = 'ATENDIDA';

INSERT INTO citas (cita_id, paciente_id, profesional_id, sede_id, fecha_hora, estado, canal, reservada_en, monto_total)
SELECT c.cita_id,
       CASE WHEN c.estado = 'DISPONIBLE' THEN NULL ELSE c.pac END,
       c.prof,
       p.sede_id,
       c.fh,
       c.estado,
       CASE WHEN c.estado = 'DISPONIBLE' THEN NULL
            ELSE (ARRAY['PRESENCIAL','CALL_CENTER','WEB'])[1 + floor(c.r2 * 3)::INT] END,
       CASE WHEN c.estado = 'DISPONIBLE' THEN NULL
            ELSE c.fh - (1 + floor(c.r2 * 20)::INT) * INTERVAL '1 day' END,
       COALESCE(i.total, 0)
FROM tmp_citas c
JOIN profesionales p ON p.profesional_id = c.prof
LEFT JOIN (SELECT cita_id, SUM(cantidad * valor_unitario) AS total FROM tmp_items GROUP BY cita_id) i
       ON i.cita_id = c.cita_id
ORDER BY c.cita_id;

SELECT setval('citas_cita_id_seq', (SELECT max(cita_id) FROM citas));

INSERT INTO cita_prestaciones (cita_id, prestacion_id, cantidad, valor_unitario)
SELECT cita_id, prestacion_id, cantidad, valor_unitario FROM tmp_items ORDER BY cita_id;

INSERT INTO pagos (cita_id, pagado_en, medio, monto)
SELECT c.cita_id,
       c.fecha_hora + random() * INTERVAL '2 hours',
       (ARRAY['TARJETA','TRANSFERENCIA','EFECTIVO','BONO'])[1 + floor(random() * 4)::INT],
       c.monto_total
FROM citas c
WHERE c.estado = 'ATENDIDA'
ORDER BY c.cita_id;

-- Estadísticas frescas y visibility map al día ANTES de la línea base,
-- para que la comparación antes/después sea justa.
VACUUM (ANALYZE);
