package es.ivanesco.oposapp.api.dtos;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class RespuestaEnvioDto {
    @NotNull(message = "El ID de la pregunta es obligatorio")
    private Integer preguntaId;

    @NotBlank(message = "La respuesta es obligatoria")
    private String respuestaDada; // 'A', 'B', 'C', 'D'

    private Integer tiempoRespuesta = 0; // seconds
}
