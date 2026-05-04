package es.ivanesco.oposapp.api.dtos;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class TestGenerateRequest {
    @NotBlank(message = "El tema es obligatorio")
    private String tema;

    @NotBlank(message = "La oposición es obligatoria")
    private String oposicion;

    @NotBlank(message = "La dificultad es obligatoria")
    private String dificultad;

    @NotNull(message = "El número de preguntas es obligatorio")
    @Min(value = 1, message = "El número mínimo de preguntas es 1")
    @Max(value = 50, message = "El número máximo de preguntas es 50")
    private Integer numPreguntas;
}
