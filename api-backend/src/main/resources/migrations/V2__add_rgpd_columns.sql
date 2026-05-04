-- ============================================================
-- MIGRACIÓN: Añadir columnas RGPD a tabla tfg.usuarios
-- Ejecutar en PostgreSQL del NAS (tfg_db, schema tfg)
-- SAFE: usa IF NOT EXISTS, no rompe datos existentes
-- ============================================================

-- Añadir columna rgpd_aceptado si no existe
ALTER TABLE tfg.usuarios
    ADD COLUMN IF NOT EXISTS rgpd_aceptado BOOLEAN NOT NULL DEFAULT FALSE;

-- Añadir columna rgpd_fecha si no existe  
ALTER TABLE tfg.usuarios
    ADD COLUMN IF NOT EXISTS rgpd_fecha TIMESTAMP WITHOUT TIME ZONE;

-- Verificar resultado
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'tfg' AND table_name = 'usuarios'
ORDER BY ordinal_position;
