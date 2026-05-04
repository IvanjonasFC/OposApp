package es.ivanesco.oposapp.api.services;

import es.ivanesco.oposapp.api.dtos.AuthRequest;
import es.ivanesco.oposapp.api.dtos.AuthResponse;
import es.ivanesco.oposapp.api.dtos.RegisterRequest;
import es.ivanesco.oposapp.api.models.RefreshToken;
import es.ivanesco.oposapp.api.models.Role;
import es.ivanesco.oposapp.api.models.Usuario;
import es.ivanesco.oposapp.api.repositories.RefreshTokenRepository;
import es.ivanesco.oposapp.api.repositories.UsuarioRepository;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.LockedException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UsuarioRepository repository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final AuthenticationManager authenticationManager;
    private final EmailService emailService;
    private final AuditService auditService;
    private final NotificacionService notificacionService;
    private final RefreshTokenRepository refreshTokenRepository;

    private static final int MAX_INTENTOS    = 4;
    private static final int BLOQUEO_MINUTOS = 15;

    public AuthResponse register(RegisterRequest request) {
        if (repository.findByEmail(request.getEmail()).isPresent()) {
            throw new RuntimeException("El email ya está registrado");
        }
        if (request.getRgpdAceptado() == null || !request.getRgpdAceptado()) {
            throw new RuntimeException("Debes aceptar la política de privacidad para registrarte");
        }

        String finalUsername;
        if (request.getNombre() != null && !request.getNombre().trim().isEmpty()) {
            finalUsername = request.getNombre().trim();
        } else if (request.getUsername() != null && !request.getUsername().trim().isEmpty()) {
            finalUsername = request.getUsername().trim();
        } else {
            finalUsername = request.getEmail().split("@")[0];
        }

        // Generamos token único UUID para verificación (expira en 24h)
        String verificacionToken = UUID.randomUUID().toString();

        var user = Usuario.builder()
                .email(request.getEmail())
                .username(finalUsername)
                .password(passwordEncoder.encode(request.getPassword()))
                .fechaRegistro(LocalDateTime.now())
                .rol(Role.USER)
                .tipoSuscripcion("FREE")
                .activo(true)
                .rgpdAceptado(true)
                .rgpdFecha(LocalDateTime.now())
                // Campos de verificación de email
                .emailVerificado(false)
                .emailVerificacionToken(verificacionToken)
                .emailVerificacionExpira(LocalDateTime.now().plusHours(24))
                .build();

        repository.save(user);

        // Auditoría: registro de nuevo usuario
        auditService.registrar("REGISTRO", "usuarios", user.getId(), null,
                "email=" + user.getEmail() + " username=" + user.getUsername());

        // Envío asíncrono best-effort (no bloquea el registro si falla)
        emailService.enviarEmailVerificacion(user.getEmail(), finalUsername, verificacionToken);

        var jwtToken = jwtService.generateToken(user);
        return AuthResponse.builder()
                .token(jwtToken)
                .usuarioId(user.getId())
                .email(user.getEmail())
                .username(user.getRealUsername())
                // nombre: campo nombre si existe, si no el username (alias legible), nunca el email
                .nombre(user.getNombre() != null && !user.getNombre().isBlank()
                        ? user.getNombre() : user.getRealUsername())
                .emailVerificado(user.getEmailVerificado() != null ? user.getEmailVerificado() : false)
                .rgpdAceptado(user.getRgpdAceptado() != null ? user.getRgpdAceptado() : false)
                .tipoSuscripcion(user.getTipoSuscripcion())
                .rol(user.getRol())
                .build();
    }

    /**
     * Verifica el token de email recibido desde el enlace del correo.
     * Comprueba que el token existe, no está expirado y no ha sido usado.
     */
    public String verificarEmail(String token) {
        var usuario = repository.findByEmailVerificacionToken(token)
                .orElseThrow(() -> new RuntimeException("Token de verificación inválido o ya usado"));

        if (usuario.getEmailVerificado()) {
            return "Tu email ya estaba verificado. Puedes iniciar sesión.";
        }
        if (usuario.getEmailVerificacionExpira().isBefore(LocalDateTime.now())) {
            throw new RuntimeException("El enlace de verificación ha expirado. Solicita uno nuevo.");
        }

        usuario.setEmailVerificado(true);
        usuario.setEmailVerificacionToken(null);   // invalidamos el token
        usuario.setEmailVerificacionExpira(null);
        repository.save(usuario);

        return "¡Email verificado correctamente! Ya puedes disfrutar de OposApp.";
    }

    public AuthResponse login(AuthRequest request) {

        // ── 1. Buscar el usuario ANTES de autenticar para poder gestionar intentos ──
        var userOpt = repository.findByEmail(request.getEmail());

        if (userOpt.isPresent()) {
            var user = userOpt.get();

            // ── 2. Comprobar si la cuenta está bloqueada ────────────────────────────
            if (user.getLockedUntil() != null && LocalDateTime.now().isBefore(user.getLockedUntil())) {
                long minutosRestantes = java.time.Duration
                        .between(LocalDateTime.now(), user.getLockedUntil()).toMinutes() + 1;
                auditService.registrar("LOGIN_BLOQUEADO", "usuarios", user.getId(), null,
                        "email=" + request.getEmail() + " bloqueado_hasta=" + user.getLockedUntil());
                throw new LockedException(
                        "Cuenta bloqueada por exceso de intentos. Inténtalo en " + minutosRestantes + " minuto(s).");
            }
        }

        // ── 3. Intentar autenticación ───────────────────────────────────────────────
        try {
            authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(
                            request.getEmail(), request.getPassword()));
        } catch (BadCredentialsException e) {
            // ── 4. Credenciales incorrectas → incrementar contador ──────────────────
            userOpt.ifPresent(user -> {
                int intentos = (user.getFailedLoginAttempts() == null ? 0 : user.getFailedLoginAttempts()) + 1;
                user.setFailedLoginAttempts(intentos);

                if (intentos >= MAX_INTENTOS) {
                    // Bloquear la cuenta 15 minutos
                    user.setLockedUntil(LocalDateTime.now().plusMinutes(BLOQUEO_MINUTOS));
                    repository.save(user);

                    // Notificar al usuario en la app
                    notificacionService.crear(
                            user.getId(),
                            "sistema",
                            "Cuenta bloqueada temporalmente",
                            "Tu cuenta ha sido bloqueada " + BLOQUEO_MINUTOS +
                            " minutos por " + MAX_INTENTOS + " intentos de acceso fallidos. " +
                            "Si no fuiste tú, cambia tu contraseña.");

                    auditService.registrar("CUENTA_BLOQUEADA", "usuarios", user.getId(), null,
                            "intentos=" + intentos + " bloqueada_hasta=" + user.getLockedUntil());
                } else {
                    repository.save(user);
                    auditService.registrar("LOGIN_FAIL", "usuarios", user.getId(), null,
                            "email=" + request.getEmail() + " intento=" + intentos + "/" + MAX_INTENTOS);
                }
            });

            // Si el usuario no existe, auditoría genérica sin userId
            if (userOpt.isEmpty()) {
                auditService.registrar("LOGIN_FAIL", "usuarios", null, null,
                        "email=" + request.getEmail());
            }
            throw e;
        }

        // ── 5. Login exitoso → resetear contador y registrar acceso ────────────────
        var user = userOpt.orElseThrow(() -> new RuntimeException("Usuario no encontrado"));
        user.setFailedLoginAttempts(0);
        user.setLockedUntil(null);
        user.setUltimoAcceso(LocalDateTime.now());
        repository.save(user);

        auditService.registrar("LOGIN_OK", "usuarios", user.getId(), null,
                "rol=" + user.getRol());

        var jwtToken = jwtService.generateToken(user);

        // Registrar token en refresh_tokens para trazabilidad (CU-02)
        refreshTokenRepository.save(RefreshToken.builder()
                .usuario(user)
                .token(jwtToken)
                .expiresAt(LocalDateTime.now().plusDays(7))
                .revoked(false)
                .build());
        return AuthResponse.builder()
                .token(jwtToken)
                .usuarioId(user.getId())
                .email(user.getEmail())
                .username(user.getRealUsername())
                .nombre(user.getNombre() != null && !user.getNombre().isBlank()
                        ? user.getNombre() : user.getRealUsername())
                .emailVerificado(user.getEmailVerificado() != null ? user.getEmailVerificado() : false)
                .rgpdAceptado(user.getRgpdAceptado() != null ? user.getRgpdAceptado() : false)
                .tipoSuscripcion(user.getTipoSuscripcion())
                .rol(user.getRol())
                .build();
    }

    /**
     * Renueva el JWT sin requerir contraseña.
     * Verifica que el token actual existe en refresh_tokens, no está revocado
     * y no ha expirado. Emite un token nuevo y revoca el anterior.
     * Llamado desde POST /api/auth/refresh con Authorization: Bearer <token-actual>
     */
    public AuthResponse refresh(String tokenActual, HttpServletRequest request) {
        // Buscar el registro en BD — debe existir, no estar revocado
        var registro = refreshTokenRepository.findByTokenAndRevokedFalse(tokenActual)
                .orElseThrow(() -> new RuntimeException("Token no válido para renovación"));

        if (registro.getExpiresAt().isBefore(LocalDateTime.now())) {
            registro.setRevoked(true);
            refreshTokenRepository.save(registro);
            throw new RuntimeException("Token expirado. Por favor, inicia sesión de nuevo.");
        }

        var user = registro.getUsuario();

        // Revocar el token antiguo
        registro.setRevoked(true);
        refreshTokenRepository.save(registro);

        // Emitir token nuevo
        String nuevoToken = jwtService.generateToken(user);

        // Registrar el nuevo token en BD
        refreshTokenRepository.save(RefreshToken.builder()
                .usuario(user)
                .token(nuevoToken)
                .expiresAt(LocalDateTime.now().plusDays(7))
                .revoked(false)
                .ipAddress(request != null ? request.getRemoteAddr() : null)
                .build());

        auditService.registrar("TOKEN_REFRESH", "refresh_tokens", user.getId(), null,
                "email=" + user.getEmail());

        return AuthResponse.builder()
                .token(nuevoToken)
                .usuarioId(user.getId())
                .email(user.getEmail())
                .username(user.getUsername())
                .nombre(user.getUsername())
                .emailVerificado(user.getEmailVerificado() != null ? user.getEmailVerificado() : false)
                .rgpdAceptado(user.getRgpdAceptado() != null ? user.getRgpdAceptado() : false)
                .tipoSuscripcion(user.getTipoSuscripcion())
                .rol(user.getRol())
                .build();
    }

    /** Limpieza nocturna de tokens expirados y revocados (cada 24h a las 03:00). */
    @Scheduled(cron = "0 0 3 * * *")
    public void limpiarTokensExpirados() {
        refreshTokenRepository.eliminarExpiradosYRevocados(LocalDateTime.now());
    }
}
