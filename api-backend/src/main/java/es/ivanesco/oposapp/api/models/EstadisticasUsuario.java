package es.ivanesco.oposapp.api.models;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "estadisticas_usuario", schema = "tfg")
public class EstadisticasUsuario {

    @Id
    @Column(name = "usuario_id")
    private Integer usuarioId;

    @OneToOne(fetch = FetchType.LAZY)
    @MapsId
    @JoinColumn(name = "usuario_id")
    private Usuario usuario;

    @Column(name = "tests_completados")
    @Builder.Default
    private Integer testsCompletados = 0;

    @Column(name = "tests_iniciados")
    @Builder.Default
    private Integer testsIniciados = 0;

    @Column(name = "tests_abandonados")
    @Builder.Default
    private Integer testsAbandonados = 0;

    @Column(name = "preguntas_respondidas")
    @Builder.Default
    private Integer preguntasRespondidas = 0;

    @Column(name = "preguntas_correctas")
    @Builder.Default
    private Integer preguntasCorrectas = 0;

    @Column(name = "preguntas_incorrectas")
    @Builder.Default
    private Integer preguntasIncorrectas = 0;

    @Column(name = "porcentaje_aciertos", columnDefinition = "numeric")
    @Builder.Default
    private Double porcentajeAciertos = 0.0;

    @Column(name = "tiempo_total_estudio_minutos")
    @Builder.Default
    private Integer tiempoTotalEstudioMinutos = 0;

    @Column(name = "promedio_tiempo_por_pregunta_seg")
    @Builder.Default
    private Integer promedioTiempoPorPreguntaSeg = 0;

    @Column(name = "dias_consecutivos")
    @Builder.Default
    private Integer diasConsecutivos = 0;

    @Column(name = "mejor_racha")
    @Builder.Default
    private Integer mejorRacha = 0;

    @Column(name = "ultima_actividad")
    @Builder.Default
    private LocalDateTime ultimaActividad = LocalDateTime.now();

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "rendimiento_por_tema", columnDefinition = "jsonb")
    @Builder.Default
    private String rendimientoPorTema = "{}";

    @Column(name = "fecha_registro")
    @Builder.Default
    private LocalDateTime fechaRegistro = LocalDateTime.now();

    @Column(name = "ultima_actualizacion")
    @Builder.Default
    private LocalDateTime ultimaActualizacion = LocalDateTime.now();

    // Since in the previous code we were dealing with date and notation in daily
    // rows,
    // the DB dump shows this table has primary key `usuario_id`, it is a 1-to-1
    // table.
    // The previous implementation mapped "fecha" and "notaMedia" which don't exist
    // here.
    // We will drop those fields.
}
