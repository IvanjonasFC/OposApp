package es.ivanesco.oposapp.api.controllers;

import es.ivanesco.oposapp.api.dtos.UpdatePerfilRequest;
import es.ivanesco.oposapp.api.models.Usuario;
import es.ivanesco.oposapp.api.services.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/user")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    /** RGPD Art. 17 — Derecho al olvido: solicitud de baja (soft delete, física en 48h) */
    @PostMapping("/delete")
    public ResponseEntity<String> deleteUser(@AuthenticationPrincipal Usuario usuario) {
        userService.softDeleteUser(usuario.getId());
        return ResponseEntity.ok("Usuario marcado para borrado (48h)");
    }

    /** RGPD Art. 20 — Portabilidad de datos: exportación JSON de toda la info del usuario */
    @GetMapping("/export")
    public ResponseEntity<Map<String, Object>> exportData(@AuthenticationPrincipal Usuario usuario) {
        return ResponseEntity.ok(userService.exportUserData(usuario.getId()));
    }

    /** Obtener perfil propio del usuario autenticado */
    @GetMapping("/me")
    public ResponseEntity<Map<String, Object>> getMe(@AuthenticationPrincipal Usuario usuario) {
        return ResponseEntity.ok(Map.of(
                "id", usuario.getId(),
                "nombre", usuario.getNombre() != null ? usuario.getNombre() : "",
                "apellidos", usuario.getApellidos() != null ? usuario.getApellidos() : "",
                "username", usuario.getUsername(),
                "email", usuario.getEmail(),
                "rol", usuario.getRol(),
                "tipoSuscripcion", usuario.getTipoSuscripcion() != null ? usuario.getTipoSuscripcion() : "GRATUITO",
                "emailVerificado", usuario.getEmailVerificado() != null && usuario.getEmailVerificado()
        ));
    }

    /** Editar nombre, apellidos y username del usuario autenticado */
    @PutMapping("/perfil")
    public ResponseEntity<Map<String, Object>> updatePerfil(
            @AuthenticationPrincipal Usuario usuario,
            @RequestBody UpdatePerfilRequest request) {
        return ResponseEntity.ok(userService.updatePerfil(usuario.getId(), request));
    }
}
