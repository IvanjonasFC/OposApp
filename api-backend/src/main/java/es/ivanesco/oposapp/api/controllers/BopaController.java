package es.ivanesco.oposapp.api.controllers;

import java.util.HashMap;
import java.util.Map;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import es.ivanesco.oposapp.api.models.Convocatoria;
import es.ivanesco.oposapp.api.models.Usuario;
import es.ivanesco.oposapp.api.services.AuditService;
import es.ivanesco.oposapp.api.services.BopaService;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/convocatorias")
@RequiredArgsConstructor
public class BopaController {

    private final BopaService bopaService;
    private final AuditService auditService;

    @GetMapping
    public ResponseEntity<Map<String, Object>> getConvocatorias(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Page<Convocatoria> result = bopaService.getConvocatorias(
                PageRequest.of(page, size,
                        Sort.by(Sort.Direction.DESC, "fechaPublicacion").and(Sort.by(Sort.Direction.DESC, "id"))));
        return ResponseEntity.ok(toPageMap(result));
    }

    // Flutter llama a /buscar; mantenemos /search por compatibilidad con
    // Swagger/Postman
    @GetMapping({ "/buscar", "/search" })
    public ResponseEntity<Map<String, Object>> searchConvocatorias(
            @RequestParam String q,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Page<Convocatoria> result = bopaService.searchConvocatorias(
                q, PageRequest.of(page, size,
                        Sort.by(Sort.Direction.DESC, "fechaPublicacion").and(Sort.by(Sort.Direction.DESC, "id"))));
        return ResponseEntity.ok(toPageMap(result));
    }

    @PostMapping("/{id}/guardar")
    public ResponseEntity<Map<String, Object>> guardarConvocatoria(
            @PathVariable Integer id,
            @AuthenticationPrincipal Usuario usuario) {
        bopaService.guardarConvocatoria(usuario.getId(), id);
        auditService.registrar("FAVORITO_GUARDADO", "convocatorias_guardadas",
                usuario.getId(), null, "convocatoriaId=" + id);
        Map<String, Object> resp = new HashMap<>();
        resp.put("success", true);
        resp.put("convocatoriaId", id);
        return ResponseEntity.ok(resp);
    }

    @DeleteMapping("/{id}/guardar")
    public ResponseEntity<Map<String, Object>> eliminarGuardada(
            @PathVariable Integer id,
            @AuthenticationPrincipal Usuario usuario) {
        bopaService.eliminarConvocatoriaGuardada(usuario.getId(), id);
        auditService.registrar("FAVORITO_ELIMINADO", "convocatorias_guardadas",
                usuario.getId(), null, "convocatoriaId=" + id);
        Map<String, Object> resp = new HashMap<>();
        resp.put("success", true);
        return ResponseEntity.ok(resp);
    }

    @GetMapping("/guardadas")
    public ResponseEntity<Map<String, Object>> getGuardadas(
            @AuthenticationPrincipal Usuario usuario,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Page<Convocatoria> result = bopaService.getConvocatoriasGuardadas(usuario.getId(), PageRequest.of(page, size));
        return ResponseEntity.ok(toPageMap(result));
    }

    // ─── Helper: convierte Page a Map estable (sin PageImpl inestable) ─────────
    private Map<String, Object> toPageMap(Page<Convocatoria> page) {
        Map<String, Object> map = new HashMap<>();
        map.put("content", page.getContent());
        map.put("page", page.getNumber());
        map.put("size", page.getSize());
        map.put("totalElements", page.getTotalElements());
        map.put("totalPages", page.getTotalPages());
        map.put("last", page.isLast());
        return map;
    }
}
