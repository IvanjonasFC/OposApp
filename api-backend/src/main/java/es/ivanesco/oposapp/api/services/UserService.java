package es.ivanesco.oposapp.api.services;

import es.ivanesco.oposapp.api.dtos.UpdatePerfilRequest;
import es.ivanesco.oposapp.api.dtos.UsuarioExportDto;
import es.ivanesco.oposapp.api.models.SolicitudBaja;
import es.ivanesco.oposapp.api.models.Usuario;
import es.ivanesco.oposapp.api.repositories.SesionTestRepository;
import es.ivanesco.oposapp.api.repositories.SolicitudBajaRepository;
import es.ivanesco.oposapp.api.repositories.UsuarioRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
@Slf4j
public class UserService {

    private final UsuarioRepository usuarioRepository;
    private final SesionTestRepository sesionTestRepository;
    private final SolicitudBajaRepository solicitudBajaRepository;
    private final AuditService auditService;

    // ──────────────────────────────────────────────────────────────────────────────
    // UPDATE PERFIL — Edición de datos básicos del usuario
    // Solo permite modificar nombre, apellidos y username (no email ni contraseña)
    // ──────────────────────────────────────────────────────────────────────────────
    @Transactional
    public Map<String, Object> updatePerfil(Integer usuarioId, UpdatePerfilRequest req) {
        Usuario usuario = usuarioRepository.findById(usuarioId)
                .orElseThrow(() -> new java.util.NoSuchElementException("Usuario no encontrado: " + usuarioId));

        if (req.getNombre() != null && !req.getNombre().isBlank())
            usuario.setNombre(req.getNombre().trim());
        if (req.getApellidos() != null)
            usuario.setApellidos(req.getApellidos().trim());
        if (req.getUsername() != null && !req.getUsername().isBlank())
            usuario.setUsername(req.getUsername().trim());

        usuarioRepository.save(usuario);
        auditService.registrar("PERFIL_ACTUALIZADO", "usuarios",
                usuarioId, null, "username=" + usuario.getUsername());
        log.info("Perfil actualizado — usuarioId={}", usuarioId);

        return Map.of(
                "id", usuario.getId(),
                "nombre", usuario.getNombre() != null ? usuario.getNombre() : "",
                "apellidos", usuario.getApellidos() != null ? usuario.getApellidos() : "",
                "username", usuario.getUsername(),
                "email", usuario.getEmail()
        );
    }

    // ──────────────────────────────────────────────────────────────────────────────
    // SOFT DELETE — RGPD Art. 17 (Derecho al olvido)
    // 1. Desactiva el usuario inmediatamente (activo = false → no puede hacer login)
    // 2. Registra el evento en solicitudes_baja con estado "pendiente"
    // 3. El job cleanUpDeletedUsers() ejecutará la eliminación física a las 48 h
    // ──────────────────────────────────────────────────────────────────────────────
    @Transactional
    public void softDeleteUser(Integer usuarioId) {
        softDeleteUser(usuarioId, null);
    }

    @Transactional
    public void softDeleteUser(Integer usuarioId, String motivo) {
        Usuario usuario = usuarioRepository.findById(usuarioId)
                .orElseThrow(() -> new java.util.NoSuchElementException("Usuario no encontrado: " + usuarioId));

        // Paso 1: inhabilitar cuenta inmediatamente
        usuario.setActivo(false);
        usuarioRepository.save(usuario);

        // Paso 2: registrar en solicitudes_baja → cumplimiento RGPD Art. 17
        SolicitudBaja solicitudBaja = SolicitudBaja.builder()
                .usuario(usuario)
                .motivo(motivo != null ? motivo : "Solicitud del usuario")
                .estado("pendiente")
                .build();
        solicitudBajaRepository.save(solicitudBaja);

        auditService.registrar("SOLICITUD_BAJA", "solicitudes_baja",
                usuarioId, null, "email=" + usuario.getEmail());

        log.info("RGPD Art.17 — usuario {} marcado para baja. Eliminación física en 48h.", usuarioId);
    }

    // ──────────────────────────────────────────────────────────────────────────────
    // EXPORT — RGPD Art. 20 (Portabilidad de datos)
    // IMPORTANTE: usa UsuarioExportDto para NUNCA serializar password_hash, salt,
    // emailVerificacionToken ni otros campos de seguridad interna.
    // ──────────────────────────────────────────────────────────────────────────────
    public Map<String, Object> exportUserData(Integer usuarioId) {
        Usuario usuario = usuarioRepository.findById(usuarioId)
                .orElseThrow(() -> new java.util.NoSuchElementException("Usuario no encontrado: " + usuarioId));
        var tests = sesionTestRepository.findByUsuarioIdOrderByFechaInicioDesc(usuarioId);

        auditService.registrar("EXPORTACION_DATOS", "usuarios",
                usuarioId, null, "email=" + usuario.getEmail());

        return Map.of(
                "usuario", UsuarioExportDto.from(usuario),
                "sesiones_test", tests);
    }

    // ──────────────────────────────────────────────────────────────────────────────
    // JOB — Eliminación física cada hora.
    // Busca solicitudes_baja "pendiente" cuya fecha_solicitud > 48 h y borra el usuario.
    // Al borrar el Usuario en cascada se eliminan sus datos asociados (ON DELETE CASCADE en BD).
    // ──────────────────────────────────────────────────────────────────────────────
    @Scheduled(cron = "0 0 * * * *") // cada hora en punto
    @Transactional
    public void cleanUpDeletedUsers() {
        LocalDateTime threshold = LocalDateTime.now().minusHours(48);

        List<SolicitudBaja> pendientes = solicitudBajaRepository.findByEstado("pendiente");

        for (SolicitudBaja solicitud : pendientes) {
            if (solicitud.getFechaSolicitud() != null
                    && solicitud.getFechaSolicitud().isBefore(threshold)) {

                Usuario u = solicitud.getUsuario();
                Integer uid = u.getId();

                solicitud.setEstado("completado");
                solicitud.setFechaEjecucion(LocalDateTime.now());
                solicitudBajaRepository.save(solicitud);

                auditService.registrar("USUARIO_ELIMINADO", "usuarios",
                        uid, null, "RGPD_Art17=eliminacion_fisica_48h");

                usuarioRepository.delete(u);
                log.info("RGPD Art.17 — usuario {} eliminado físicamente tras 48h.", uid);
            }
        }
    }
}
