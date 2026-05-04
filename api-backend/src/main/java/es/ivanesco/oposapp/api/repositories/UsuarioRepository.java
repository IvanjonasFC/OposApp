package es.ivanesco.oposapp.api.repositories;

import es.ivanesco.oposapp.api.models.Usuario;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Map;
import java.util.Optional;

@Repository
public interface UsuarioRepository extends JpaRepository<Usuario, Integer> {

    Optional<Usuario> findByEmail(String email);
    Optional<Usuario> findByEmailVerificacionToken(String token);
    List<Usuario> findByActivoFalse();

    /**
     * Resumen de usuarios para la tabla del panel admin (RF-15).
     * Devuelve: id, username, email, rol, tipo_suscripcion, activo, ultimo_acceso, fecha_registro
     */
    @Query(value = """
        SELECT
            u.id            AS "id",
            u.username      AS "username",
            u.email         AS "email",
            u.rol           AS "rol",
            u.tipo_suscripcion AS "tipoSuscripcion",
            u.activo        AS "activo",
            u.ultimo_acceso AS "ultimoAcceso",
            u.fecha_registro AS "fechaRegistro"
        FROM tfg.usuarios u
        ORDER BY u.fecha_registro DESC
        """, nativeQuery = true)
    List<Map<String, Object>> findAllUsuariosResumen();

    /**
     * Últimas 100 entradas del audit_log para el panel admin.
     * ip_address es tipo inet en PG → se castea a text para que Jackson lo serialice sin problemas.
     * timestamp → se serializa como ISO-8601 en UTC explícitamente con TO_CHAR para evitar
     * que el driver JDBC aplique la zona del JVM al deserializar el tipo timestamp.
     */
    @Query(value = """
        SELECT
            al.id               AS "id",
            al.tabla            AS "tabla",
            al.operacion        AS "operacion",
            al.usuario_id       AS "usuarioId",
            al.datos_anteriores AS "datosAnteriores",
            al.datos_nuevos     AS "datosNuevos",
            al.ip_address::text AS "ipAddress",
            al.user_agent       AS "userAgent",
            TO_CHAR(al.timestamp AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS') AS "timestamp"
        FROM tfg.audit_log al
        ORDER BY al.timestamp DESC
        LIMIT 100
        """, nativeQuery = true)
    List<Map<String, Object>> findAuditLogs();
}
