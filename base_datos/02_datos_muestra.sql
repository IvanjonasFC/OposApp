-- ============================================================
--  OposApp — Datos de demostración
--  Ejecutar DESPUÉS de 01_schema.sql
--
--  Incluye datos mínimos para probar la aplicación:
--    · 2 usuarios (ADMIN + USER)
--    · 3 convocatorias del BOPA de ejemplo
--    · 1 test generado con 3 preguntas
--    · Estadísticas de progreso
--    · Historial de scraping de muestra
--    · 1 anuncio de ejemplo
--
--  Contraseña de ambos usuarios: Test1234!
--  NOTA: Los emails son ficticios (datos de muestra para el TFG)
-- ============================================================

SET search_path TO tfg;

-- ── Usuarios ───────────────────────────────────────────────
-- Contraseñas hasheadas con BCrypt factor 10 → Test1234!
INSERT INTO tfg.usuarios
  (username, email, password_hash, salt, nombre, rol, tipo_suscripcion,
   activo, rgpd_aceptado, rgpd_fecha_aceptacion, email_verificado, fecha_registro)
VALUES
  ('admin_demo', 'admin@oposapp.example',
   '$2a$10$8K1p/a0dR6U4OSdvGhvIbO5/cUFVe8xKxNdRFQb5b5DF9LzHpqmfi',
   'default_salt', 'Administrador', 'ADMIN', 'PREMIUM',
   TRUE, TRUE, NOW(), TRUE, NOW() - INTERVAL '30 days'),

  ('usuario_demo', 'usuario@oposapp.example',
   '$2a$10$8K1p/a0dR6U4OSdvGhvIbO5/cUFVe8xKxNdRFQb5b5DF9LzHpqmfi',
   'default_salt', 'Usuario Demo', 'USER', 'FREE',
   TRUE, TRUE, NOW(), FALSE, NOW() - INTERVAL '15 days')
ON CONFLICT (email) DO NOTHING;

-- ── Convocatorias BOPA de muestra ─────────────────────────
INSERT INTO tfg.convocatorias
  (titulo, organismo, descripcion, url, fecha_publicacion, estado, categoria, num_plazas)
VALUES
  ('Auxiliar Administrativo — Ayuntamiento de Oviedo',
   'Ayuntamiento de Oviedo',
   'Convocatoria para cubrir 12 plazas de Auxiliar Administrativo mediante oposición libre. Grupo C2.',
   'https://www.bopa.es/bopa/2025/12/30/2025-12345.html',
   '2025-12-30', 'activa', 'Auxiliar Administrativo', 12),

  ('Policía Local — Ayuntamiento de Gijón',
   'Ayuntamiento de Gijón',
   'Concurso-oposición para 8 plazas de Policía Local. Escala básica, categoría oficial.',
   'https://www.bopa.es/bopa/2026/01/15/2026-00145.html',
   '2026-01-15', 'activa', 'Policía Local', 8),

  ('Celador — Hospital Universitario Central de Asturias',
   'Servicio de Salud del Principado de Asturias (SESPA)',
   'Convocatoria de 25 plazas de Celador para el HUCA. Grupo E. Oposición libre.',
   'https://www.bopa.es/bopa/2026/02/03/2026-00312.html',
   '2026-02-03', 'activa', 'Celador', 25)
ON CONFLICT DO NOTHING;

-- ── Test de muestra ────────────────────────────────────────
INSERT INTO tfg.tests (titulo, oposicion, tema, dificultad, num_preguntas, created_by)
SELECT 'Constitución Española — Media', 'Auxiliar Administrativo',
       'Artículo 14 Constitución Española', 'Media', 3, id
FROM tfg.usuarios WHERE email = 'admin@oposapp.example'
LIMIT 1
ON CONFLICT DO NOTHING;

-- ── Solicitud de generación asociada ──────────────────────
INSERT INTO tfg.solicitudes_generacion
  (usuario_id, test_id, tema, oposicion, dificultad, num_preguntas, estado, fecha_completado)
SELECT u.id, t.id,
       'Artículo 14 Constitución Española', 'Auxiliar Administrativo', 'Media', 3,
       'completado', NOW() - INTERVAL '2 hours'
FROM tfg.usuarios u, tfg.tests t
WHERE u.email = 'admin@oposapp.example'
  AND t.titulo = 'Constitución Española — Media'
LIMIT 1
ON CONFLICT DO NOTHING;

-- ── Preguntas del test ────────────────────────────────────
INSERT INTO tfg.preguntas
  (test_id, texto_pregunta, opcion_a, opcion_b, opcion_c, opcion_d,
   respuesta_correcta, explicacion, tema, oposicion, dificultad)
SELECT t.id,
       '¿Qué establece el Artículo 14 de la Constitución Española?',
       'A) El derecho a la educación',
       'B) La igualdad de todos los españoles ante la ley sin discriminación',
       'C) La libertad de expresión',
       'D) El derecho al trabajo',
       'B',
       'El Art. 14 CE establece el principio de igualdad: los españoles son iguales ante la ley, sin que pueda prevalecer discriminación por razón de nacimiento, raza, sexo, religión u opinión.',
       'Artículo 14 Constitución Española', 'Auxiliar Administrativo', 'Media'
FROM tfg.tests t WHERE t.titulo = 'Constitución Española — Media'
LIMIT 1;

INSERT INTO tfg.preguntas
  (test_id, texto_pregunta, opcion_a, opcion_b, opcion_c, opcion_d,
   respuesta_correcta, explicacion, tema, oposicion, dificultad)
SELECT t.id,
       '¿Qué tipo de discriminaciones prohíbe expresamente el Artículo 14?',
       'A) Solo por razón de sexo y raza',
       'B) Por nacimiento, raza, sexo, religión, opinión o cualquier otra condición',
       'C) Únicamente las discriminaciones laborales',
       'D) Solo las discriminaciones religiosas',
       'B',
       'El Art. 14 prohíbe cualquier discriminación por nacimiento, raza, sexo, religión, opinión o cualquier otra condición o circunstancia personal o social.',
       'Artículo 14 Constitución Española', 'Auxiliar Administrativo', 'Media'
FROM tfg.tests t WHERE t.titulo = 'Constitución Española — Media'
LIMIT 1;

INSERT INTO tfg.preguntas
  (test_id, texto_pregunta, opcion_a, opcion_b, opcion_c, opcion_d,
   respuesta_correcta, explicacion, tema, oposicion, dificultad)
SELECT t.id,
       '¿En qué título de la Constitución Española se encuentra el Artículo 14?',
       'A) Título I — De los derechos y deberes fundamentales',
       'B) Título II — De la Corona',
       'C) Título III — De las Cortes Generales',
       'D) Título Preliminar',
       'A',
       'El Art. 14 se ubica en el Título I "De los derechos y deberes fundamentales", Capítulo II, Sección 1ª, que agrupa los derechos fundamentales y libertades públicas.',
       'Artículo 14 Constitución Española', 'Auxiliar Administrativo', 'Media'
FROM tfg.tests t WHERE t.titulo = 'Constitución Española — Media'
LIMIT 1;

-- ── Estadísticas del usuario admin ────────────────────────
INSERT INTO tfg.estadisticas_usuario
  (usuario_id, tests_completados, preguntas_respondidas, respuestas_correctas, dias_consecutivos)
SELECT id, 10, 100, 26, 0
FROM tfg.usuarios WHERE email = 'admin@oposapp.example'
ON CONFLICT (usuario_id) DO UPDATE
  SET tests_completados = 10, preguntas_respondidas = 100, respuestas_correctas = 26;

-- ── Historial de scraping de muestra ─────────────────────
INSERT INTO tfg.historial_scraping
  (estado, fecha_scraping, convocatorias_nuevas, errores, duracion_ms)
VALUES
  ('completado', NOW() - INTERVAL '1 day',   3, 0, 4200),
  ('completado', NOW() - INTERVAL '8 days',  1, 0, 3800),
  ('completado', NOW() - INTERVAL '15 days', 2, 0, 4100)
ON CONFLICT DO NOTHING;

-- ── Anuncio de muestra ────────────────────────────────────
INSERT INTO tfg.anuncios (titulo, imagen_url, url_destino, activo)
VALUES ('Aprende con OposApp Premium', 'https://via.placeholder.com/400x80', 'https://oposapp.es', TRUE)
ON CONFLICT DO NOTHING;

SELECT 'Datos de muestra cargados correctamente.' AS resultado;
