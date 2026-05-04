package es.ivanesco.oposapp.api.repositories;

import es.ivanesco.oposapp.api.models.Anuncio;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.Optional;

@Repository
public interface AnuncioRepository extends JpaRepository<Anuncio, Integer> {

    /**
     * Anuncio activo aleatorio respetando fechas de vigencia.
     * fecha_inicio NULL → sin límite de inicio. fecha_fin NULL → sin límite de fin.
     */
    @Query(value = """
        SELECT * FROM tfg.anuncios
        WHERE activo = true
          AND (fecha_inicio IS NULL OR fecha_inicio <= :ahora)
          AND (fecha_fin    IS NULL OR fecha_fin    >= :ahora)
        ORDER BY RANDOM()
        LIMIT 1
        """, nativeQuery = true)
    Optional<Anuncio> findRandomActiveAd(@Param("ahora") LocalDateTime ahora);
}
