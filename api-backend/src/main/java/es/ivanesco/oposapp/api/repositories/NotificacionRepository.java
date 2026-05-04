package es.ivanesco.oposapp.api.repositories;

import es.ivanesco.oposapp.api.models.Notificacion;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface NotificacionRepository extends JpaRepository<Notificacion, Integer> {

    // Todas las notificaciones del usuario, más recientes primero
    List<Notificacion> findByUsuarioIdOrderByFechaCreacionDesc(Integer usuarioId);

    // Cuántas no leídas tiene el usuario (para el badge del HomeScreen)
    long countByUsuarioIdAndLeidaFalse(Integer usuarioId);

    // Marcar todas como leídas de un usuario
    @Modifying
    @Query(value = """
        UPDATE tfg.notificaciones
        SET leida = true, fecha_lectura = NOW()
        WHERE usuario_id = :usuarioId AND leida = false
        """, nativeQuery = true)
    int marcarTodasComoLeidas(@Param("usuarioId") Integer usuarioId);

    @Modifying
    @Query(value = "DELETE FROM tfg.notificaciones WHERE usuario_id = :usuarioId",
           nativeQuery = true)
    int eliminarTodasDelUsuario(@Param("usuarioId") Integer usuarioId);
}
