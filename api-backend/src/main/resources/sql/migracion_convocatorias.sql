-- Migración convocatorias v2 (continueOnError=true en Spring)
ALTER TABLE tfg.convocatorias ALTER COLUMN bopa_numero TYPE VARCHAR(100);
ALTER TABLE tfg.convocatorias ADD COLUMN IF NOT EXISTS num_plazas INTEGER DEFAULT 0;
ALTER TABLE tfg.convocatorias ADD CONSTRAINT uq_convocatorias_bopa_titulo UNIQUE (bopa_numero, titulo);
CREATE INDEX IF NOT EXISTS idx_convocatorias_fts ON tfg.convocatorias USING GIN (to_tsvector('spanish', titulo || ' ' || COALESCE(organismo,'')));
