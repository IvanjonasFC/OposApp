package es.ivanesco.oposapp.api.dtos;

import lombok.Data;

@Data
public class UpdatePerfilRequest {
    private String nombre;
    private String apellidos;
    private String username;
}
