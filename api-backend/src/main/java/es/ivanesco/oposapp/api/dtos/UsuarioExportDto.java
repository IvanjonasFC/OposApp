package es.ivanesco.oposapp.api.dtos;

import es.ivanesco.oposapp.api.models.Role;
import es.ivanesco.oposapp.api.models.Usuario;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * DTO de exportación RGPD Art. 20 — Portabilidad de datos.
 *
 * NUNCA incluir: password_hash, salt, emailVerificacionToken,
 * failedLoginAttempts, lockedUntil.
 * Solo datos que el usuario reconoce como suyos y tienen valor para él.
 */
@Data
@Builder
public class UsuarioExportDto {

    private Integer id;
    private String email;
    private String username;
    private Role rol;
    private String tipoSuscripcion;
    private LocalDateTime fechaRegistro;
    private LocalDateTime ultimoAcceso;
    private Boolean rgpdAceptado;
    private LocalDateTime rgpdFecha;
    private Boolean emailVerificado;

    /** Factoría: construye el DTO desde la entidad JPA sin exponer campos sensibles */
    public static UsuarioExportDto from(Usuario u) {
        return UsuarioExportDto.builder()
                .id(u.getId())
                .email(u.getEmail())
                .username(u.getRealUsername())
                .rol(u.getRol())
                .tipoSuscripcion(u.getTipoSuscripcion())
                .fechaRegistro(u.getFechaRegistro())
                .ultimoAcceso(u.getUltimoAcceso())
                .rgpdAceptado(u.getRgpdAceptado())
                .rgpdFecha(u.getRgpdFecha())
                .emailVerificado(u.getEmailVerificado())
                .build();
    }
}
