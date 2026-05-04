package es.ivanesco.oposapp.api.models;

import com.fasterxml.jackson.annotation.JsonIgnore;
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
@Table(name = "preguntas", schema = "tfg")
public class Pregunta {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "test_id")
    private Integer testId;

    @Column(name = "texto_pregunta", nullable = false, columnDefinition = "TEXT")
    private String textoPregunta;

    @Column(name = "opcion_a", nullable = false, columnDefinition = "TEXT")
    private String opcionA;

    @Column(name = "opcion_b", nullable = false, columnDefinition = "TEXT")
    private String opcionB;

    @Column(name = "opcion_c", nullable = false, columnDefinition = "TEXT")
    private String opcionC;

    @Column(name = "opcion_d", nullable = false, columnDefinition = "TEXT")
    private String opcionD;

    @Column(name = "respuesta_correcta", length = 1, columnDefinition = "bpchar")
    private String respuestaCorrecta;

    @Column(columnDefinition = "TEXT")
    private String explicacion;

    @Column(length = 300)
    private String tema;

    @Column(length = 200)
    private String oposicion;

    @Column(length = 20)
    private String dificultad;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "solicitud_id")
    @JsonIgnore  // No serializar — evita LazyInitializationException
    private SolicitudGeneracion solicitud;

    @CreationTimestamp
    @Column(name = "fecha_creacion", updatable = false)
    private LocalDateTime fechaCreacion;
}
