package es.ivanesco.oposapp.api.controllers;

import es.ivanesco.oposapp.api.models.Pregunta;
import es.ivanesco.oposapp.api.repositories.PreguntaRepository;
import es.ivanesco.oposapp.api.repositories.SolicitudGeneracionRepository;
import es.ivanesco.oposapp.api.repositories.UsuarioRepository;
import es.ivanesco.oposapp.api.services.AuditService;
import es.ivanesco.oposapp.api.services.OllamaService;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

/**
 * Panel de administración — solo accesible con ROLE_ADMIN.
 * Endpoints consumidos por admin_service.dart en Flutter:
 *   GET /api/admin/ollama/status  → estado del servidor IA
 *   GET /api/admin/stats          → DashboardStats { totalUsuarios, preguntasGeneradasHoy, solicitudesPendientes }
 *   GET /api/admin/audit          → List<AuditLog> (últimas 100 entradas)
 *   GET /api/admin/preguntas      → Page<Pregunta>
 *   GET /api/admin/usuarios       → lista de usuarios con métricas básicas
 *   PUT /api/admin/usuarios/{id}/rol    → cambiar rol de un usuario
 *   PUT /api/admin/usuarios/{id}/estado → activar/desactivar cuenta
 */
@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminController {

    private final OllamaService ollamaService;
    private final UsuarioRepository usuarioRepository;
    private final PreguntaRepository preguntaRepository;
    private final SolicitudGeneracionRepository solicitudGeneracionRepository;
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder(12);
    private final AuditService auditService;

    @PersistenceContext
    private EntityManager em;


    // ─── Ollama status (ya existía) ───────────────────────────────────────────

    @GetMapping("/ollama/status")
    public ResponseEntity<Map<String, Object>> getOllamaStatus() {
        boolean online = ollamaService.isOnline();
        return ResponseEntity.ok(Map.of(
                "online", online,
                "modelo", "qwen2.5",
                "url", ollamaService.getUrl()   // URL leida de configuracion, no hardcodeada
        ));
    }

    // ─── Stats para el DashboardStats de Flutter ──────────────────────────────

    /**
     * Devuelve { totalUsuarios, preguntasGeneradasHoy, solicitudesPendientes }
     * Flutter lo mapea directamente en DashboardStats.fromJson()
     */
    @GetMapping("/stats")
    public ResponseEntity<Map<String, Object>> getStats() {
        long totalUsuarios = usuarioRepository.count();

        LocalDateTime inicioDia = LocalDate.now().atStartOfDay();
        long preguntasHoy = preguntaRepository.countByFechaCreacionAfter(inicioDia);

        long solicitudesPendientes = solicitudGeneracionRepository
                .countByEstado("pendiente");

        return ResponseEntity.ok(Map.of(
                "totalUsuarios", totalUsuarios,
                "preguntasGeneradasHoy", preguntasHoy,
                "solicitudesPendientes", solicitudesPendientes
        ));
    }


    // ─── Audit log ────────────────────────────────────────────────────────────

    /**
     * Últimas 100 entradas del audit_log.
     * Flutter mapea cada fila en AuditLog.fromJson() — campos: id, tabla, operacion,
     * usuarioId, datosAnteriores, datosNuevos, ipAddress, userAgent, timestamp.
     * ip_address es tipo inet en PG → lo devolvemos como String con query nativa.
     */
    @GetMapping("/audit")
    public ResponseEntity<List<Map<String, Object>>> getAuditLogs() {
        List<Map<String, Object>> logs = usuarioRepository.findAuditLogs();
        return ResponseEntity.ok(logs);
    }

    // ─── Preguntas paginadas ──────────────────────────────────────────────────

    /**
     * Flutter espera { content: [...], totalElements, totalPages, ... }
     * Spring Page<T> serializa eso automáticamente.
     */
    @GetMapping("/preguntas")
    public ResponseEntity<Page<Pregunta>> getPreguntas(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {

        Page<Pregunta> resultado = preguntaRepository.findAll(
                PageRequest.of(page, size, Sort.by("id").descending()));
        return ResponseEntity.ok(resultado);
    }

    // ─── Gestión de usuarios (RF-17, RF-19) ──────────────────────────────────

    /** Lista todos los usuarios con sus datos básicos para la tabla del panel admin. */
    @GetMapping("/usuarios")
    public ResponseEntity<List<Map<String, Object>>> getUsuarios() {
        List<Map<String, Object>> usuarios = usuarioRepository.findAllUsuariosResumen();
        return ResponseEntity.ok(usuarios);
    }


    /** Cambia el rol de un usuario: USER, PREMIUM o ADMIN. */
    @PutMapping("/usuarios/{id}/rol")
    public ResponseEntity<Map<String, Object>> cambiarRol(
            @PathVariable Integer id,
            @RequestBody Map<String, String> body) {

        String nuevoRol = body.getOrDefault("rol", "USER").toUpperCase();
        if (!List.of("USER", "PREMIUM", "ADMIN").contains(nuevoRol)) {
            return ResponseEntity.badRequest()
                    .body(Map.of("error", "Rol no válido. Usa: USER, PREMIUM o ADMIN"));
        }
        usuarioRepository.findById(id).ifPresent(u -> {
            u.setRol(es.ivanesco.oposapp.api.models.Role.valueOf(nuevoRol));
            usuarioRepository.save(u);
            auditService.registrar("ROL_CAMBIADO", "usuarios", id,
                    null, "nuevoRol=" + nuevoRol);
        });
        return ResponseEntity.ok(Map.of("ok", true, "nuevoRol", nuevoRol));
    }

    /** Activa o desactiva la cuenta de un usuario (campo activo en BD). */
    @PutMapping("/usuarios/{id}/estado")
    public ResponseEntity<Map<String, Object>> cambiarEstado(
            @PathVariable Integer id,
            @RequestBody Map<String, Boolean> body) {

        boolean activo = body.getOrDefault("activo", true);
        usuarioRepository.findById(id).ifPresent(u -> {
            u.setActivo(activo);
            usuarioRepository.save(u);
            auditService.registrar(activo ? "CUENTA_ACTIVADA" : "CUENTA_DESACTIVADA",
                    "usuarios", id, null, "usuarioId=" + id);
        });
        return ResponseEntity.ok(Map.of("ok", true, "activo", activo));
    }

    /** Cambia la contrasena de un usuario desde el panel admin. */
    @PutMapping("/usuarios/{id}/password")
    public ResponseEntity<Map<String, Object>> cambiarPassword(
            @PathVariable Integer id,
            @RequestBody Map<String, String> body) {

        String nuevaPassword = body.getOrDefault("password", "");
        if (nuevaPassword.length() < 8) {
            return ResponseEntity.badRequest()
                    .body(Map.of("error", "La contrasena debe tener al menos 8 caracteres"));
        }
        return usuarioRepository.findById(id).map(u -> {
            u.setPassword(passwordEncoder.encode(nuevaPassword));
            usuarioRepository.save(u);
            auditService.registrar("PASSWORD_CAMBIADA", "usuarios", id,
                    null, "cambiadoPorAdmin=true");
            return ResponseEntity.ok(Map.<String, Object>of("ok", true));
        }).orElse(ResponseEntity.notFound().build());
    }

    /**
     * Health check completo del sistema para el panel admin.
     * Devuelve el estado de: BD, scraping BOPA, tests generados, Ollama y usuarios.
     */
    @GetMapping("/system-health")
    public ResponseEntity<Map<String, Object>> getSystemHealth() {
        Map<String, Object> health = new java.util.LinkedHashMap<>();

        // 1. Base de datos — total convocatorias
        try {
            Long totalConvocatorias = (Long) em.createNativeQuery(
                "SELECT COUNT(*) FROM tfg.convocatorias").getSingleResult();
            Long convocatoriasUltimaSemana = (Long) em.createNativeQuery(
                "SELECT COUNT(*) FROM tfg.convocatorias WHERE fecha_scraping >= NOW() - INTERVAL '7 days'")
                .getSingleResult();
            health.put("bd_ok", true);
            health.put("total_convocatorias", totalConvocatorias);
            health.put("convocatorias_ultima_semana", convocatoriasUltimaSemana);
        } catch (Exception e) {
            health.put("bd_ok", false);
            health.put("bd_error", e.getMessage());
        }

        // 2. Último scraping del BOPA desde historial_scraping
        try {
            Object[] lastScraping = (Object[]) em.createNativeQuery(
                "SELECT estado, fecha_scraping, convocatorias_nuevas, errores " +
                "FROM tfg.historial_scraping " +
                "ORDER BY fecha_scraping DESC LIMIT 1")
                .getSingleResult();
            health.put("ultimo_scraping_estado", lastScraping[0]);
            health.put("ultimo_scraping_fecha", lastScraping[1] != null ? lastScraping[1].toString() : null);
            health.put("ultimo_scraping_nuevas", lastScraping[2]);
            health.put("ultimo_scraping_errores", lastScraping[3]);
            health.put("scraping_ok", "completado".equals(lastScraping[0]));
        } catch (Exception e) {
            health.put("scraping_ok", false);
            health.put("ultimo_scraping_estado", "sin_datos");
            health.put("ultimo_scraping_fecha", null);
        }

        // 3. Tests — total generados y últimas 24h
        try {
            Long totalTests = (Long) em.createNativeQuery(
                "SELECT COUNT(*) FROM tfg.tests").getSingleResult();
            Long testsHoy = (Long) em.createNativeQuery(
                "SELECT COUNT(*) FROM tfg.solicitudes_generacion " +
                "WHERE estado = 'completado' AND fecha_completado >= NOW() - INTERVAL '24 hours'")
                .getSingleResult();
            Long erroresHoy = (Long) em.createNativeQuery(
                "SELECT COUNT(*) FROM tfg.solicitudes_generacion " +
                "WHERE estado = 'error' AND fecha_solicitud >= NOW() - INTERVAL '24 hours'")
                .getSingleResult();
            health.put("total_tests", totalTests);
            health.put("tests_ultimas_24h", testsHoy);
            health.put("errores_ia_24h", erroresHoy);
            health.put("tests_ok", erroresHoy == 0);
        } catch (Exception e) {
            health.put("tests_ok", false);
        }

        // 4. Ollama
        boolean ollamaOnline = ollamaService.isOnline();
        health.put("ollama_ok", ollamaOnline);
        health.put("ollama_modelo", "qwen2.5");

        // 5. Usuarios activos
        try {
            Long usuariosActivos = (Long) em.createNativeQuery(
                "SELECT COUNT(*) FROM tfg.usuarios WHERE activo = true").getSingleResult();
            Long loginHoy = (Long) em.createNativeQuery(
                "SELECT COUNT(*) FROM tfg.audit_log " +
                "WHERE operacion = 'LOGIN_OK' AND timestamp >= NOW() - INTERVAL '24 hours'")
                .getSingleResult();
            health.put("usuarios_activos", usuariosActivos);
            health.put("logins_ultimas_24h", loginHoy);
        } catch (Exception e) {
            health.put("usuarios_activos", 0);
        }

        // Estado global
        boolean todoOk = Boolean.TRUE.equals(health.get("bd_ok"))
                && Boolean.TRUE.equals(health.get("ollama_ok"));
        health.put("sistema_ok", todoOk);
        health.put("timestamp", java.time.LocalDateTime.now().toString());

        return ResponseEntity.ok(health);
    }
}
