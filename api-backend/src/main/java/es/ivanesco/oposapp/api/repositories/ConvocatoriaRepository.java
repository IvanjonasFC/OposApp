package es.ivanesco.oposapp.api.repositories;

import es.ivanesco.oposapp.api.models.Convocatoria;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

@Repository
public interface ConvocatoriaRepository extends JpaRepository<Convocatoria, Integer> {

    // Búsqueda full-text usando el índice GIN de la BD
    @Query(value = "SELECT * FROM tfg.convocatorias c WHERE to_tsvector('spanish', c.titulo || ' ' || COALESCE(c.organismo,'')) @@ to_tsquery('spanish', :query) AND c.activo = true",
           countQuery = "SELECT count(*) FROM tfg.convocatorias c WHERE to_tsvector('spanish', c.titulo || ' ' || COALESCE(c.organismo,'')) @@ to_tsquery('spanish', :query) AND c.activo = true",
           nativeQuery = true)
    Page<Convocatoria> fullTextSearch(@Param("query") String query, Pageable pageable);

    // Convocatorias guardadas por usuario
    @Query(value = "SELECT c.* FROM tfg.convocatorias c INNER JOIN tfg.convocatorias_guardadas cg ON c.id = cg.convocatoria_id WHERE cg.usuario_id = :usuarioId ORDER BY cg.fecha_guardado DESC",
           countQuery = "SELECT count(*) FROM tfg.convocatorias_guardadas cg WHERE cg.usuario_id = :usuarioId",
           nativeQuery = true)
    Page<Convocatoria> findGuardadasByUsuarioId(@Param("usuarioId") Integer usuarioId, Pageable pageable);

    // Guardar convocatoria (INSERT ON CONFLICT DO NOTHING — evita duplicados)
    @Modifying
    @Transactional
    @Query(value = "INSERT INTO tfg.convocatorias_guardadas (usuario_id, convocatoria_id, fecha_guardado) VALUES (:usuarioId, :convocatoriaId, NOW()) ON CONFLICT DO NOTHING",
           nativeQuery = true)
    void guardarConvocatoria(@Param("usuarioId") Integer usuarioId, @Param("convocatoriaId") Integer convocatoriaId);

    // Eliminar de favoritos
    @Modifying
    @Transactional
    @Query(value = "DELETE FROM tfg.convocatorias_guardadas WHERE usuario_id = :usuarioId AND convocatoria_id = :convocatoriaId",
           nativeQuery = true)
    void eliminarGuardada(@Param("usuarioId") Integer usuarioId, @Param("convocatoriaId") Integer convocatoriaId);
}
