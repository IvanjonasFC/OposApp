package es.ivanesco.oposapp.api.controllers;

import es.ivanesco.oposapp.api.models.Usuario;
import es.ivanesco.oposapp.api.services.EstadisticasService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/estadisticas")
@RequiredArgsConstructor
public class EstadisticasController {

    private final EstadisticasService estadisticasService;

    /**
     * GET /api/estadisticas/mias — estadísticas del usuario autenticado.
     * Sustituye a /{usuarioId} para evitar IDOR (acceso a datos ajenos).
     */
    @GetMapping("/mias")
    public ResponseEntity<Map<String, Object>> getMisEstadisticas(
            @AuthenticationPrincipal Usuario usuario) {
        return ResponseEntity.ok(estadisticasService.getEstadisticas(usuario.getId()));
    }

    /**
     * GET /api/estadisticas/{usuarioId} — mantenido por compatibilidad.
     * Solo accesible si el usuarioId coincide con el usuario autenticado.
     */
    @GetMapping("/{usuarioId}")
    public ResponseEntity<Map<String, Object>> getEstadisticas(
            @PathVariable Integer usuarioId,
            @AuthenticationPrincipal Usuario usuario) {
        // Seguridad: solo puede ver sus propias estadísticas
        if (!usuario.getId().equals(usuarioId)) {
            return ResponseEntity.status(403).build();
        }
        return ResponseEntity.ok(estadisticasService.getEstadisticas(usuarioId));
    }
}
