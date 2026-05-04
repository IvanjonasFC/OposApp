package es.ivanesco.oposapp.api.dtos;

import es.ivanesco.oposapp.api.models.SolicitudGeneracion;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * DTO de respuesta para SolicitudGeneracion.
 * Evita serializar la entidad JPA directamente (que incluye Usuario/UserDetails
 * y causa bucles de serialización → HTTP 400/500).
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SolicitudGeneracionDto {

    private Integer id;
    private String tema;
    private String oposicion;
    private String dificultad;
    private Integer numPreguntas;
    private String estado;
    private Integer testId;
    private LocalDateTime fechaSolicitud;
    private LocalDateTime fechaCompletado;

    /** Veces que el usuario ha completado este test (sesiones con completado=true) */
    private Integer vecesRealizado;

    /** Porcentaje de aciertos de la sesión más reciente (null si nunca realizado) */
    private Double ultimaNota;

    /** Factoría estática para convertir entidad → DTO (sin estadísticas) */
    public static SolicitudGeneracionDto from(SolicitudGeneracion s) {
        return SolicitudGeneracionDto.builder()
                .id(s.getId())
                .tema(s.getTema())
                .oposicion(s.getOposicion())
                .dificultad(s.getDificultad())
                .numPreguntas(s.getNumPreguntas())
                .estado(s.getEstado())
                .testId(s.getTestId())
                .fechaSolicitud(s.getFechaSolicitud())
                .fechaCompletado(s.getFechaCompletado())
                .vecesRealizado(0)
                .ultimaNota(null)
                .build();
    }

    /** Factoría con estadísticas de sesiones */
    public static SolicitudGeneracionDto from(SolicitudGeneracion s, int vecesRealizado, Double ultimaNota) {
        return SolicitudGeneracionDto.builder()
                .id(s.getId())
                .tema(s.getTema())
                .oposicion(s.getOposicion())
                .dificultad(s.getDificultad())
                .numPreguntas(s.getNumPreguntas())
                .estado(s.getEstado())
                .testId(s.getTestId())
                .fechaSolicitud(s.getFechaSolicitud())
                .fechaCompletado(s.getFechaCompletado())
                .vecesRealizado(vecesRealizado)
                .ultimaNota(ultimaNota)
                .build();
    }
}
