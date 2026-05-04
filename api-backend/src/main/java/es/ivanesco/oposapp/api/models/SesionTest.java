package es.ivanesco.oposapp.api.models;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "sesiones_test", schema = "tfg")
public class SesionTest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "usuario_id")
    private Usuario usuario;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "test_id")
    private TestEntity test;

    @CreationTimestamp
    @Column(name = "fecha_inicio", updatable = false)
    private LocalDateTime fechaInicio;

    @Column(name = "fecha_fin")
    private LocalDateTime fechaFin;

    @Column(name = "total_preguntas")
    private Integer totalPreguntas;

    @Column(name = "preguntas_correctas")
    @Builder.Default
    private Integer preguntasCorrectas = 0;

    @Column(name = "preguntas_incorrectas")
    @Builder.Default
    private Integer preguntasIncorrectas = 0;

    @Column(name = "puntuacion_porcentaje", precision = 5, scale = 2)
    private BigDecimal puntuacionPorcentaje;

    @Column(name = "tiempo_total")
    private Integer tiempoTotal;

    @Column(length = 20)
    @Builder.Default
    private String estado = "en_progreso";

    @Column(name = "ip_sesion", columnDefinition = "inet")
    @JdbcTypeCode(SqlTypes.INET)
    private String ipSesion;

    @Builder.Default
    private Boolean completado = false;

}
