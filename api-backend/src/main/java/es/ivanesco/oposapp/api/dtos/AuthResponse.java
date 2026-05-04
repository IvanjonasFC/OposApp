package es.ivanesco.oposapp.api.dtos;

import es.ivanesco.oposapp.api.models.Role;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class AuthResponse {
    private String token;
    private Integer usuarioId;
    private String email;
    private Role rol;
    private String username;
    private String tipoSuscripcion;

    // Campos que Flutter necesita para el perfil
    private String nombre;
    private String apellidos;
    private Boolean emailVerificado;
    private Boolean rgpdAceptado;
}
