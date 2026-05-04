package es.ivanesco.oposapp.api.repositories;

import es.ivanesco.oposapp.api.models.EstadisticasUsuario;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

@Repository
public interface EstadisticasUsuarioRepository extends JpaRepository<EstadisticasUsuario, Integer> {

    @Query("SELECT e FROM EstadisticasUsuario e WHERE e.usuario.id = :usuarioId AND e.ultimaActualizacion >= :fechaInicio ORDER BY e.ultimaActualizacion ASC")
    List<EstadisticasUsuario> findEvolucionUltimos30Dias(@Param("usuarioId") Integer usuarioId,
            @Param("fechaInicio") LocalDate fechaInicio);

    @Query("SELECT e FROM EstadisticasUsuario e WHERE e.usuario.id = :usuarioId ORDER BY e.ultimaActualizacion DESC")
    List<EstadisticasUsuario> findHistorialCompleto(@Param("usuarioId") Integer usuarioId, Pageable pageable);

    /**
     * Vista temas_debiles_usuario — top 5 temas con peor rendimiento del usuario.
     */
    @Query(value = """
        SELECT tema                           AS "tema",
               oposicion                     AS "oposicion",
               preguntas_intentadas          AS "preguntasIntentadas",
               aciertos                      AS "aciertos",
               ROUND(porcentaje_aciertos, 1) AS "porcentajeAciertos"
        FROM tfg.temas_debiles_usuario
        WHERE usuario_id = :usuarioId
        ORDER BY porcentaje_aciertos ASC
        LIMIT 5
        """, nativeQuery = true)
    List<Map<String, Object>> findTemasDebiles(@Param("usuarioId") Integer usuarioId);

    /**
     * Vista evolucion_usuario_30dias — evolución diaria del porcentaje de aciertos.
     */
    @Query(value = """
        SELECT TO_CHAR(fecha, 'YYYY-MM-DD')  AS "fecha",
               tests_realizados              AS "testsRealizados",
               ROUND(porcentaje_promedio, 1) AS "porcentajePromedio"
        FROM tfg.evolucion_usuario_30dias
        WHERE usuario_id = :usuarioId
        ORDER BY fecha ASC
        """, nativeQuery = true)
    List<Map<String, Object>> findEvolucion30Dias(@Param("usuarioId") Integer usuarioId);
}
