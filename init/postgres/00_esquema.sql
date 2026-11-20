-- ============================================================
-- Salud Integral 360 · EP2 IDY1103
-- 00_esquema.sql: modelo relacional (PostgreSQL)
--
-- Adaptación del EP2_dataset.sql de referencia al caso clínico:
--   ep2_stores      -> sedes
--   ep2_customers   -> pacientes
--   ep2_products    -> prestaciones
--   ep2_orders      -> citas          (además funciona como agenda)
--   ep2_order_items -> cita_prestaciones
--   ep2_payments    -> pagos
--   (nuevas)        -> especialidades, profesionales
--
-- Igual que en la referencia, se crean SOLO claves primarias y foráneas.
-- No hay índices en columnas de filtro ni en las FK: es intencional,
-- para que existan cuellos de botella que optimizar en la EP2.
-- ============================================================

CREATE TABLE sedes (
  sede_id   SERIAL PRIMARY KEY,
  nombre    TEXT NOT NULL,
  region    TEXT NOT NULL
);

CREATE TABLE especialidades (
  especialidad_id SERIAL PRIMARY KEY,
  nombre          TEXT NOT NULL UNIQUE
);

CREATE TABLE profesionales (
  profesional_id  SERIAL PRIMARY KEY,
  nombre_completo TEXT NOT NULL,
  especialidad_id INT  NOT NULL REFERENCES especialidades(especialidad_id),
  sede_id         INT  NOT NULL REFERENCES sedes(sede_id),
  activo          BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE pacientes (
  paciente_id      BIGSERIAL PRIMARY KEY,
  rut              TEXT NOT NULL,
  nombre_completo  TEXT NOT NULL,
  email            TEXT NOT NULL,
  fecha_nacimiento DATE NOT NULL,
  comuna           TEXT NOT NULL,
  prevision        TEXT NOT NULL,          -- FONASA | ISAPRE | PARTICULAR
  creado_en        TIMESTAMP NOT NULL
);

CREATE TABLE prestaciones (
  prestacion_id SERIAL PRIMARY KEY,
  codigo        TEXT NOT NULL,
  nombre        TEXT NOT NULL,
  tipo          TEXT NOT NULL,             -- Consulta | Examen | Procedimiento | Imagenología | Laboratorio
  valor         NUMERIC(10,2) NOT NULL,
  activa        BOOLEAN NOT NULL DEFAULT TRUE
);

-- Cada fila es un bloque de 20 minutos de la agenda de un profesional.
-- estado = 'DISPONIBLE' y paciente_id NULL  -> hora libre.
-- Luego: AGENDADA -> CONFIRMADA -> ATENDIDA | NO_ASISTE, o ANULADA.
CREATE TABLE citas (
  cita_id        BIGSERIAL PRIMARY KEY,
  paciente_id    BIGINT REFERENCES pacientes(paciente_id),
  profesional_id INT    NOT NULL REFERENCES profesionales(profesional_id),
  sede_id        INT    NOT NULL REFERENCES sedes(sede_id),
  fecha_hora     TIMESTAMP NOT NULL,
  estado         VARCHAR(20) NOT NULL,
  canal          VARCHAR(20),              -- PRESENCIAL | CALL_CENTER | WEB (NULL si está libre)
  reservada_en   TIMESTAMP,
  monto_total    NUMERIC(12,2) NOT NULL DEFAULT 0
);

CREATE TABLE cita_prestaciones (
  item_id        BIGSERIAL PRIMARY KEY,
  cita_id        BIGINT NOT NULL REFERENCES citas(cita_id),
  prestacion_id  INT    NOT NULL REFERENCES prestaciones(prestacion_id),
  cantidad       INT    NOT NULL CHECK (cantidad > 0),
  valor_unitario NUMERIC(10,2) NOT NULL
);

CREATE TABLE pagos (
  pago_id   BIGSERIAL PRIMARY KEY,
  cita_id   BIGINT NOT NULL REFERENCES citas(cita_id),
  pagado_en TIMESTAMP NOT NULL,
  medio     VARCHAR(20) NOT NULL,          -- TARJETA | TRANSFERENCIA | EFECTIVO | BONO
  monto     NUMERIC(12,2) NOT NULL
);
