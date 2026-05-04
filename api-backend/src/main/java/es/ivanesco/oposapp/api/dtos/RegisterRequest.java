package es.ivanesco.oposapp.api.dtos;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class RegisterRequest {

    @NotBlank(message = "El email es obligatorio")
    @Email(message = "Formato de email inválido")
    private String email;

    @NotBlank(message = "La contraseña es obligatoria")
    private String password;

    // Flutter manda "nombre" como nombre de usuario → se mapea a username en BD
    private String nombre;

    // Alias por si el cliente manda "username" directamente (compatibilidad)
    private String username;

    // Campo RGPD — Flutter lo envía, se persiste en BD si existe la columna
    private Boolean rgpdAceptado;

    // Apellidos opcionales — Flutter los puede mandar
    private String apellidos;

    /**
     * Devuelve el username efectivo: prioridad "nombre" > "username" > email
     * Esto permite que Flutter mande "nombre" y funcione sin cambiar la BD
     */
    public String getEffectiveUsername() {
        if (nombre != null && !nombre.trim().isEmpty()) return nombre.trim();
        if (username != null && !username.trim().isEmpty()) return username.trim();
        return email;
    }
}
