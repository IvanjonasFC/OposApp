package es.ivanesco.oposapp.api.services;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Servicio de auditoría — escribe en tfg.audit_log de forma asíncrona.
 * Registra eventos de autenticación, tests, admin y RGPD.
 *
 * Eventos definidos:
 *   Auth:   LOGIN_OK, LOGIN_FAIL, REGISTRO, TOKEN_REFRESH, LOGOUT
 *   Tests:  TEST_GENERADO, TEST_COMPLETADO, TEST_ERROR, TEST_EVALUADO
 *   Admin:  ROL_CAMBIADO, CUENTA_ACTIVADA, CUENTA_DESACTIVADA, PASSWORD_CAMBIADA
 *   RGPD:   SOLICITUD_BAJA, EXPORTACION_DATOS
 *   BOPA:   FAVORITO_GUARDADO, FAVORITO_ELIMINADO
 */
@Service
public class AuditService {

    @PersistenceContext
    private EntityManager em;

    /**
     * Registra un evento en audit_log.
     * REQUIRES_NEW abre su propia transacción independiente:
     * - Si la transacción del llamante hace rollback, el log se preserva igualmente.
     * - Si el log falla, no cancela la transacción del llamante.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void registrar(String operacion, String tabla,
                          Integer usuarioId, String ip, String detalle) {
        try {
            String safeIp = (ip != null && !ip.isBlank()) ? ip : "0.0.0.0";
            em.createNativeQuery("""
                INSERT INTO tfg.audit_log
                    (tabla, operacion, usuario_id, datos_nuevos, ip_address, timestamp)
                VALUES
                    (:tabla, :op, :uid, :detalle, CAST(:ip AS inet), NOW())
            """)
            .setParameter("tabla",   tabla)
            .setParameter("op",      operacion)
            .setParameter("uid",     usuarioId)
            .setParameter("detalle", detalle)
            .setParameter("ip",      safeIp)
            .executeUpdate();
        } catch (Exception e) {
            // Auditoría nunca debe romper el flujo principal
            System.err.println("[AuditService] Error registrando evento " + operacion + ": " + e.getMessage());
        }
    }

    /** Shortcut sin detalle */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void registrar(String operacion, String tabla, Integer usuarioId, String ip) {
        registrar(operacion, tabla, usuarioId, ip, null);
    }
}
