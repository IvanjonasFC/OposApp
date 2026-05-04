package es.ivanesco.oposapp.api.services;

import es.ivanesco.oposapp.api.models.Notificacion;
import es.ivanesco.oposapp.api.repositories.NotificacionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Servicio centralizado para crear notificaciones persistentes en BD.
 * Se usa desde TestService, BopaService, etc.
 * REQUIRES_NEW: si la transacción llamante falla, la notificación se graba igualmente.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class NotificacionService {

    private final NotificacionRepository notificacionRepository;

    /** Tipos válidos (constraint chk_tipo_notif en BD):
     *  'test_completado' | 'nueva_convocatoria' | 'sistema' | 'premium' | 'recordatorio' */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void crear(Integer usuarioId, String tipo, String titulo, String mensaje) {
        try {
            Notificacion n = Notificacion.builder()
                    .usuarioId(usuarioId)
                    .tipo(tipo)
                    .titulo(titulo)
                    .mensaje(mensaje)
                    .leida(false)
                    .build();
            notificacionRepository.save(n);
            log.debug("Notificación creada — usuario={} tipo={} titulo={}", usuarioId, tipo, titulo);
        } catch (Exception e) {
            log.error("Error creando notificación para usuario {}: {}", usuarioId, e.getMessage());
        }
    }
}
