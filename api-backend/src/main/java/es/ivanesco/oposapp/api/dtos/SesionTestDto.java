package es.ivanesco.oposapp.api.dtos;

import es.ivanesco.oposapp.api.models.SesionTest;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * DTO de respuesta para SesionTest.
 * Evita serializar entidades JPA con relaciones lazy (Usuario, TestEntity)
 * que causan ByteBuddyInterceptor → HTTP 400/500.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SesionTestDto {

    private Integer id;
    private Integer testId;
    private String testTema;
    private Integer totalPreguntas;
    private Integer preguntasCorrectas;
    private Integer preguntasIncorrectas;
    private BigDecimal puntuacionPorcentaje;
    private Integer tiempoTotal;
    private String estado;
    private Boolean completado;
    private LocalDateTime fechaInicio;
    private LocalDateTime fechaFin;

    public static SesionTestDto from(SesionTest s) {
        return SesionTestDto.builder()
                .id(s.getId())
                .testId(s.getTest() != null ? s.getTest().getId() : null)
                .testTema(s.getTest() != null ? s.getTest().getTema() : null)
                .totalPreguntas(s.getTotalPreguntas())
                .preguntasCorrectas(s.getPreguntasCorrectas())
                .preguntasIncorrectas(s.getPreguntasIncorrectas())
                .puntuacionPorcentaje(s.getPuntuacionPorcentaje())
                .tiempoTotal(s.getTiempoTotal())
                .estado(s.getEstado())
                .completado(s.getCompletado())
                .fechaInicio(s.getFechaInicio())
                .fechaFin(s.getFechaFin())
                .build();
    }
}
