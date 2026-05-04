package es.ivanesco.oposapp.api.controllers;

import es.ivanesco.oposapp.api.models.Notificacion;
import es.ivanesco.oposapp.api.models.Usuario;
import es.ivanesco.oposapp.api.repositories.NotificacionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * Endpoints de notificaciones para el usuario autenticado.
 * Flutter llama a:
 *   GET    /api/notificaciones                  → lista completa
 *   GET    /api/notificaciones/no-leidas/count  → { "count": N }
 *   PATCH  /api/notificaciones/{id}/leer        → marca una como leída
 *   PATCH  /api/notificaciones/leer-todas       → marca todas como leídas
 *   DELETE /api/notificaciones/{id}             → elimina una notificación
 *   DELETE /api/notificaciones/todas            → elimina todas las del usuario
 */
@RestController
@RequestMapping("/api/notificaciones")
@RequiredArgsConstructor
public class NotificacionesController {

    private final NotificacionRepository notificacionRepository;

    /** Lista todas las notificaciones del usuario autenticado (más recientes primero).
     *  Devuelve creadaEn en lugar de fechaCreacion para compatibilidad con Flutter. */
    @GetMapping
    public ResponseEntity<List<Map<String, Object>>> getNotificaciones(
            @AuthenticationPrincipal Usuario usuario) {

        List<Notificacion> lista = notificacionRepository
                .findByUsuarioIdOrderByFechaCreacionDesc(usuario.getId());

        List<Map<String, Object>> response = lista.stream().map(n -> {
            Map<String, Object> m = new java.util.LinkedHashMap<>();
            m.put("id", n.getId());
            m.put("titulo", n.getTitulo());
            m.put("mensaje", n.getMensaje());
            m.put("tipo", n.getTipo());
            m.put("leida", n.getLeida());
            m.put("creadaEn", n.getFechaCreacion() != null ? n.getFechaCreacion().toString() : null);
            m.put("referenciaId", null);
            return m;
        }).toList();

        return ResponseEntity.ok(response);
    }

    /** Devuelve { "count": N } con las notificaciones no leídas — badge del HomeScreen. */
    @GetMapping("/no-leidas/count")
    public ResponseEntity<Map<String, Long>> getBadge(
            @AuthenticationPrincipal Usuario usuario) {

        long count = notificacionRepository
                .countByUsuarioIdAndLeidaFalse(usuario.getId());
        return ResponseEntity.ok(Map.of("count", count));
    }

    /** Marca una notificación individual como leída. */
    @Transactional
    @PatchMapping("/{id}/leer")
    public ResponseEntity<Map<String, Boolean>> marcarLeida(
            @PathVariable Integer id,
            @AuthenticationPrincipal Usuario usuario) {

        notificacionRepository.findById(id).ifPresent(n -> {
            if (n.getUsuarioId().equals(usuario.getId())) {
                n.setLeida(true);
                n.setFechaLectura(java.time.LocalDateTime.now());
                notificacionRepository.save(n);
            }
        });
        return ResponseEntity.ok(Map.of("ok", true));
    }

    /** Marca todas las notificaciones del usuario como leídas. */
    @Transactional
    @PatchMapping("/leer-todas")
    public ResponseEntity<Map<String, Object>> marcarTodasLeidas(
            @AuthenticationPrincipal Usuario usuario) {

        int actualizadas = notificacionRepository
                .marcarTodasComoLeidas(usuario.getId());
        return ResponseEntity.ok(Map.of(
                "ok", true,
                "actualizadas", actualizadas
        ));
    }

    /** Elimina una notificación del usuario. */
    @Transactional
    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, Boolean>> eliminarNotificacion(
            @PathVariable Integer id,
            @AuthenticationPrincipal Usuario usuario) {

        notificacionRepository.findById(id).ifPresent(n -> {
            if (n.getUsuarioId().equals(usuario.getId())) {
                notificacionRepository.delete(n);
            }
        });
        return ResponseEntity.ok(Map.of("ok", true));
    }

    /** Elimina todas las notificaciones del usuario. */
    @Transactional
    @DeleteMapping("/todas")
    public ResponseEntity<Map<String, Object>> eliminarTodas(
            @AuthenticationPrincipal Usuario usuario) {

        int eliminadas = notificacionRepository.eliminarTodasDelUsuario(usuario.getId());
        return ResponseEntity.ok(Map.of("ok", true, "eliminadas", eliminadas));
    }
}
