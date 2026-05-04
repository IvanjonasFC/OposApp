package es.ivanesco.oposapp.api.controllers;

import es.ivanesco.oposapp.api.dtos.AuthRequest;
import es.ivanesco.oposapp.api.dtos.AuthResponse;
import es.ivanesco.oposapp.api.dtos.RegisterRequest;
import es.ivanesco.oposapp.api.services.AuthService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
@Tag(name = "Autenticación", description = "Registro, login y verificación de email")
public class AuthController {

    private final AuthService authService;

    @Operation(summary = "Registrar nuevo opositor",
               description = "Crea la cuenta y envía email de confirmación automáticamente")
    @PostMapping("/registro")
    public ResponseEntity<AuthResponse> register(
            @Valid @RequestBody RegisterRequest request) {
        return ResponseEntity.ok(authService.register(request));
    }

    @Operation(summary = "Login con email y contraseña")
    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(
            @Valid @RequestBody AuthRequest request) {
        return ResponseEntity.ok(authService.login(request));
    }

    /**
     * Renueva el JWT sin requerir contraseña.
     * El cliente envía el token actual en el header Authorization.
     * El backend verifica que existe en refresh_tokens, lo revoca y emite uno nuevo.
     * Ruta pública (no requiere JWT válido — el token puede estar casi expirado).
     */
    @Operation(summary = "Renovar JWT sin contraseña",
               description = "Enviar token actual en Authorization: Bearer <token>. " +
                             "Devuelve nuevo token si el actual existe en BD y no ha expirado.")
    @PostMapping("/refresh")
    public ResponseEntity<AuthResponse> refresh(
            @RequestHeader("Authorization") String authHeader,
            HttpServletRequest request) {
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return ResponseEntity.badRequest().build();
        }
        final String token = authHeader.substring(7);
        return ResponseEntity.ok(authService.refresh(token, request));
    }

    /**
     * Endpoint que recibe el clic del enlace del email de verificación.
     * Ruta pública (no requiere JWT) — configurada en SecurityConfig.
     * Devuelve HTML simple para que el usuario vea un mensaje en el navegador.
     */
    @Operation(summary = "Verificar email desde enlace del correo",
               description = "Token UUID de 24h. Marca email_verificado=true en BD.")
    @GetMapping("/verificar-email")
    public ResponseEntity<String> verificarEmail(@RequestParam String token) {
        String mensaje = authService.verificarEmail(token);
        // Devolvemos HTML mínimo para que el usuario vea algo bonito en el navegador
        String html = """
                <!DOCTYPE html><html lang="es"><head><meta charset="UTF-8"/>
                <title>OposApp - Verificación</title>
                <style>body{font-family:sans-serif;display:flex;justify-content:center;
                align-items:center;height:100vh;margin:0;background:#f4f4f4;}
                .card{background:#fff;padding:40px;border-radius:12px;text-align:center;
                box-shadow:0 4px 20px rgba(0,0,0,.1);max-width:400px;}
                h2{color:#FF6B00;}p{color:#555;}</style></head>
                <body><div class="card"><h2>✅ OposApp</h2><p>%s</p>
                <p style="margin-top:24px;font-size:13px;color:#aaa;">
                Ya puedes cerrar esta ventana y abrir la app.</p></div></body></html>
                """.formatted(mensaje);
        return ResponseEntity.ok()
                .header("Content-Type", "text/html;charset=UTF-8")
                .body(html);
    }
}
