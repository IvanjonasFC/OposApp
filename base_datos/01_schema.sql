-- ============================================================
--  OposApp — Schema completo de la base de datos
--  Motor:  PostgreSQL 14+
--  Schema: tfg
--
--  Crea todas las tablas, índices y relaciones desde cero.
--  Ejecutar antes de 02_datos_muestra.sql
--
--  Uso:
--    psql -U postgres -d tu_base_de_datos -f 01_schema.sql
-- ============================================================

-- Crear schema si no existe
CREATE SCHEMA IF NOT EXISTS tfg;
SET search_path TO tfg;

-- ── Extensiones ────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS pg_trgm;  -- búsqueda full-text aproximada
CREATE EXTENSION IF NOT EXISTS unaccent; -- búsqueda sin tildes

-- ── usuarios ───────────────────────────────────────────────
-- Tabla central de autenticación.
-- El backend usa el email como identificador de login (no el username).
-- Los roles posibles son: USER, PREMIUM, ADMIN.
CREATE TABLE IF NOT EXISTS tfg.usuarios (
    id                        SERIAL       PRIMARY KEY,
    username                  VARCHAR(50)  NOT NULL UNIQUE,
    email                     VARCHAR(100) NOT NULL UNIQUE,
    password_hash             VARCHAR(255) NOT NULL,
    salt                      VARCHAR(100) NOT NULL DEFAULT 'default_salt',
    nombre                    VARCHAR(100),
    apellidos                 VARCHAR(150),
    rol                       VARCHAR(20)  NOT NULL DEFAULT 'USER',
    tipo_suscripcion          VARCHAR(20)  NOT NULL DEFAULT 'FREE',
    activo                    BOOLEAN      NOT NULL DEFAULT TRUE,
    rgpd_aceptado             BOOLEAN      DEFAULT FALSE,
    rgpd_fecha_aceptacion     TIMESTAMP,
    email_verificado          BOOLEAN      DEFAULT FALSE,
    email_verificacion_token  VARCHAR(255),
    email_verificacion_expira TIMESTAMP,
    failed_login_attempts     INTEGER      DEFAULT 0,
    locked_until              TIMESTAMP,
    ultimo_acceso             TIMESTAMP,
    fecha_registro            TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- ── tests ──────────────────────────────────────────────────
-- Cada test generado por la IA. Contiene metadatos del test
-- (tema, oposición, dificultad) pero no las preguntas en sí
-- (esas están en la tabla preguntas).
CREATE TABLE IF NOT EXISTS tfg.tests (
    id            SERIAL       PRIMARY KEY,
    titulo        VARCHAR(255),
    oposicion     VARCHAR(100),
    tema          VARCHAR(255),
    dificultad    VARCHAR(20),
    num_preguntas INTEGER,
    created_by    INTEGER REFERENCES tfg.usuarios(id) ON DELETE SET NULL,
    created_at    TIMESTAMP    DEFAULT NOW()
);

-- ── solicitudes_generacion ─────────────────────────────────
-- Cola de peticiones al modelo de IA.
-- Estados posibles: pendiente → procesando → completado / error
-- Flutter hace polling a este estado cada 3 segundos.
CREATE TABLE IF NOT EXISTS tfg.solicitudes_generacion (
    id               SERIAL      PRIMARY KEY,
    usuario_id       INTEGER     NOT NULL REFERENCES tfg.usuarios(id) ON DELETE CASCADE,
    test_id          INTEGER     REFERENCES tfg.tests(id) ON DELETE SET NULL,
    tema             VARCHAR(255),
    oposicion        VARCHAR(100),
    dificultad       VARCHAR(20),
    num_preguntas    INTEGER,
    estado           VARCHAR(20) DEFAULT 'pendiente',
    fecha_solicitud  TIMESTAMP   DEFAULT NOW(),
    fecha_completado TIMESTAMP
);

-- ── preguntas ──────────────────────────────────────────────
-- Preguntas tipo test generadas por Ollama.
-- Cada pregunta tiene 4 opciones (A-D), la respuesta correcta
-- y una explicación generada por la IA.
CREATE TABLE IF NOT EXISTS tfg.preguntas (
    id                 SERIAL     PRIMARY KEY,
    test_id            INTEGER    REFERENCES tfg.tests(id) ON DELETE CASCADE,
    solicitud_id       INTEGER    REFERENCES tfg.solicitudes_generacion(id) ON DELETE SET NULL,
    texto_pregunta     TEXT,
    opcion_a           TEXT,
    opcion_b           TEXT,
    opcion_c           TEXT,
    opcion_d           TEXT,
    respuesta_correcta VARCHAR(1),
    explicacion        TEXT,
    tema               VARCHAR(255),
    oposicion          VARCHAR(100),
    dificultad         VARCHAR(20),
    fecha_creacion     TIMESTAMP  DEFAULT NOW()
);

-- ── sesiones_test ──────────────────────────────────────────
-- Cada vez que un usuario realiza un test se crea una sesión.
-- La puntuación se almacena como porcentaje (0-100).
CREATE TABLE IF NOT EXISTS tfg.sesiones_test (
    id                    SERIAL     PRIMARY KEY,
    usuario_id            INTEGER    NOT NULL REFERENCES tfg.usuarios(id) ON DELETE CASCADE,
    test_id               INTEGER    REFERENCES tfg.tests(id) ON DELETE CASCADE,
    puntuacion_porcentaje NUMERIC(5,2),
    fecha_inicio          TIMESTAMP  DEFAULT NOW(),
    fecha_fin             TIMESTAMP,
    completada            BOOLEAN    DEFAULT FALSE
);

-- ── respuestas_usuario ─────────────────────────────────────
-- Respuesta individual del usuario a cada pregunta de una sesión.
-- tiempo_ms registra cuánto tardó en responder (para estadísticas).
CREATE TABLE IF NOT EXISTS tfg.respuestas_usuario (
    id          SERIAL    PRIMARY KEY,
    sesion_id   INTEGER   NOT NULL REFERENCES tfg.sesiones_test(id) ON DELETE CASCADE,
    pregunta_id INTEGER   REFERENCES tfg.preguntas(id) ON DELETE CASCADE,
    respuesta   VARCHAR(1),
    correcta    BOOLEAN,
    tiempo_ms   INTEGER
);

-- ── estadisticas_usuario ───────────────────────────────────
-- KPIs agregados de cada usuario. Se actualizan tras cada sesión.
-- Relación 1:1 con usuarios (un registro por usuario).
CREATE TABLE IF NOT EXISTS tfg.estadisticas_usuario (
    usuario_id            INTEGER PRIMARY KEY REFERENCES tfg.usuarios(id) ON DELETE CASCADE,
    tests_completados     INTEGER DEFAULT 0,
    preguntas_respondidas INTEGER DEFAULT 0,
    respuestas_correctas  INTEGER DEFAULT 0,
    dias_consecutivos     INTEGER DEFAULT 0,
    ultima_sesion         TIMESTAMP
);

-- ── convocatorias ──────────────────────────────────────────
-- Convocatorias de empleo público. Se rellenan automáticamente
-- mediante scraping periódico del BOPA (Boletín Oficial del
-- Principado de Asturias) usando un workflow externo.
CREATE TABLE IF NOT EXISTS tfg.convocatorias (
    id                SERIAL       PRIMARY KEY,
    titulo            VARCHAR(500),
    organismo         VARCHAR(255),
    descripcion       TEXT,
    url               VARCHAR(1000),
    fecha_publicacion DATE,
    fecha_fin_plazo   DATE,
    estado            VARCHAR(50)  DEFAULT 'activa',
    categoria         VARCHAR(100),
    fecha_scraping    TIMESTAMP    DEFAULT NOW(),
    num_plazas        INTEGER,
    boletin           VARCHAR(100)
);

-- Índice full-text para búsqueda en título y descripción
CREATE INDEX IF NOT EXISTS idx_convocatorias_fts
    ON tfg.convocatorias
    USING gin(to_tsvector('spanish',
        coalesce(titulo, '') || ' ' || coalesce(descripcion, '')));

-- ── convocatorias_guardadas ────────────────────────────────
-- Favoritos de cada usuario. Relación N:M entre usuarios y convocatorias.
CREATE TABLE IF NOT EXISTS tfg.convocatorias_guardadas (
    usuario_id       INTEGER   NOT NULL REFERENCES tfg.usuarios(id) ON DELETE CASCADE,
    convocatoria_id  INTEGER   NOT NULL REFERENCES tfg.convocatorias(id) ON DELETE CASCADE,
    fecha_guardado   TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (usuario_id, convocatoria_id)
);

-- ── notificaciones ─────────────────────────────────────────
-- Mensajes del sistema al usuario (test completado, cuenta bloqueada, etc.).
CREATE TABLE IF NOT EXISTS tfg.notificaciones (
    id         SERIAL    PRIMARY KEY,
    usuario_id INTEGER   NOT NULL REFERENCES tfg.usuarios(id) ON DELETE CASCADE,
    tipo       VARCHAR(50),
    titulo     VARCHAR(255),
    mensaje    TEXT,
    leida      BOOLEAN   DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ── refresh_tokens ─────────────────────────────────────────
-- Tokens JWT emitidos. Permite revocar tokens sin esperar a que expiren.
CREATE TABLE IF NOT EXISTS tfg.refresh_tokens (
    id         SERIAL    PRIMARY KEY,
    usuario_id INTEGER   NOT NULL REFERENCES tfg.usuarios(id) ON DELETE CASCADE,
    token      TEXT      NOT NULL UNIQUE,
    expires_at TIMESTAMP NOT NULL,
    revoked    BOOLEAN   DEFAULT FALSE,
    ip_address VARCHAR(50),
    created_at TIMESTAMP DEFAULT NOW()
);

-- ── audit_log ──────────────────────────────────────────────
-- Registro inmutable de acciones. El backend escribe aquí cada
-- operación relevante (login, generación de test, cambio de rol, etc.).
-- Solo lectura para el panel de administración.
CREATE TABLE IF NOT EXISTS tfg.audit_log (
    id               SERIAL      PRIMARY KEY,
    operacion        VARCHAR(100) NOT NULL,
    tabla            VARCHAR(100),
    usuario_id       INTEGER,
    datos_anteriores TEXT,
    datos_nuevos     TEXT,
    ip_address       VARCHAR(50),
    user_agent       VARCHAR(500),
    timestamp        TIMESTAMP   DEFAULT NOW()
);

-- ── anuncios ───────────────────────────────────────────────
-- Sistema de monetización interno. Los anuncios se sirven desde
-- el backend (sin SDKs externos de rastreo).
CREATE TABLE IF NOT EXISTS tfg.anuncios (
    id          SERIAL    PRIMARY KEY,
    titulo      VARCHAR(255),
    imagen_url  VARCHAR(1000),
    url_destino VARCHAR(1000),
    activo      BOOLEAN   DEFAULT TRUE,
    created_at  TIMESTAMP DEFAULT NOW()
);

-- ── solicitudes_baja ───────────────────────────────────────
-- Cola de borrado por derecho al olvido (RGPD Art. 17).
-- El usuario solicita la baja → se desactiva inmediatamente →
-- el backend borra físicamente los datos en 48 horas.
CREATE TABLE IF NOT EXISTS tfg.solicitudes_baja (
    id           SERIAL    PRIMARY KEY,
    usuario_id   INTEGER   NOT NULL REFERENCES tfg.usuarios(id) ON DELETE CASCADE,
    motivo       TEXT,
    estado       VARCHAR(20) DEFAULT 'pendiente',
    created_at   TIMESTAMP DEFAULT NOW(),
    ejecutado_at TIMESTAMP
);

-- ── reportes ───────────────────────────────────────────────
-- Informe IA generado tras cada test completado.
-- Contiene la nota final y un consejo personalizado de mejora.
CREATE TABLE IF NOT EXISTS tfg.reportes (
    id           SERIAL    PRIMARY KEY,
    solicitud_id INTEGER   REFERENCES tfg.solicitudes_generacion(id) ON DELETE CASCADE,
    nota         NUMERIC(4,2),
    consejo_ia   TEXT,
    created_at   TIMESTAMP DEFAULT NOW()
);

-- ── historial_scraping ─────────────────────────────────────
-- Registro de cada ejecución del proceso de scraping del BOPA.
-- Permite al panel de administración consultar la actividad
-- reciente sin necesidad de acceder al workflow externo.
CREATE TABLE IF NOT EXISTS tfg.historial_scraping (
    id                   SERIAL    PRIMARY KEY,
    estado               VARCHAR(50),
    fecha_scraping       TIMESTAMP DEFAULT NOW(),
    convocatorias_nuevas INTEGER   DEFAULT 0,
    errores              INTEGER   DEFAULT 0,
    duracion_ms          INTEGER
);

-- ── Verificación final ─────────────────────────────────────
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS tamaño
FROM pg_tables
WHERE schemaname = 'tfg'
ORDER BY tablename;
