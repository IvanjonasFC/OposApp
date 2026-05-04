package es.ivanesco.oposapp.api.models;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "respuestas_usuario", schema = "tfg")
public class RespuestaUsuario {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "sesion_id")
    private SesionTest sesion;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "pregunta_id")
    private Pregunta pregunta;

    @Column(name = "respuesta_seleccionada", length = 1, columnDefinition = "bpchar")
    private String respuestaSeleccionada;

    @Column(name = "es_correcta")
    private Boolean esCorrecta;

    @Column(name = "tiempo_respuesta")
    private Integer tiempoRespuesta;

    @CreationTimestamp
    @Column(name = "fecha_respuesta", updatable = false)
    private LocalDateTime fechaRespuesta;
}
