package es.ivanesco.oposapp.api.models;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "usuarios", schema = "tfg")
@JsonIgnoreProperties({"hibernateLazyInitializer", "handler", "password",
        "authorities", "accountNonExpired", "accountNonLocked",
        "credentialsNonExpired", "enabled"})
public class Usuario implements UserDetails {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(unique = true, nullable = false, length = 50)
    private String username;

    @Column(unique = true, nullable = false, length = 100)
    private String email;

    @Column(name = "password_hash", nullable = false)
    private String password;

    @Column(nullable = false, updatable = false)
    @Builder.Default
    private String salt = "default_salt";

    @Column(name = "failed_login_attempts")
    @Builder.Default
    private Integer failedLoginAttempts = 0;

    @Column(name = "locked_until")
    private LocalDateTime lockedUntil;

    @Column(name = "ultimo_acceso")
    private LocalDateTime ultimoAcceso;

    @Column(name = "fecha_registro", updatable = false)
    @Builder.Default
    private LocalDateTime fechaRegistro = LocalDateTime.now();

    @Builder.Default
    private Boolean activo = true;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    @Builder.Default
    private Role rol = Role.USER;

    @Column(name = "tipo_suscripcion", nullable = false, length = 20)
    @Builder.Default
    private String tipoSuscripcion = "FREE";

    @Column(name = "rgpd_aceptado")
    @Builder.Default
    private Boolean rgpdAceptado = false;

    @Column(name = "rgpd_fecha_aceptacion")
    private LocalDateTime rgpdFecha;

    // --- Verificación de email (columnas ya existentes en BD) ---
    @Column(name = "email_verificado")
    @Builder.Default
    private Boolean emailVerificado = false;

    @Column(name = "email_verificacion_token", length = 255)
    private String emailVerificacionToken;

    @Column(name = "email_verificacion_expira")
    private LocalDateTime emailVerificacionExpira;

    // --- Columnas añadidas en migración ---
    @Column(name = "nombre", length = 100)
    private String nombre;

    @Column(name = "apellidos", length = 150)
    private String apellidos;

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return List.of(new SimpleGrantedAuthority("ROLE_" + rol.name()));
    }

    @Override
    public String getPassword() {
        return password;
    }

    @Override
    public String getUsername() {
        return email;
    }

    public String getRealUsername() {
        return username;
    }

    @Override
    public boolean isAccountNonExpired() { return true; }

    @Override
    public boolean isAccountNonLocked() {
        return lockedUntil == null || LocalDateTime.now().isAfter(lockedUntil);
    }

    @Override
    public boolean isCredentialsNonExpired() { return true; }

    @Override
    public boolean isEnabled() {
        return activo != null && activo;
    }
}
