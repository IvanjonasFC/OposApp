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
@Table(name = "solicitudes_generacion", schema = "tfg")
public class SolicitudGeneracion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "usuario_id")
    @JsonIgnore  // Serializado via DTO, no directamente
    private Usuario usuario;

    @Column(nullable = false, length = 200)
    private String oposicion;

    @Column(nullable = false, length = 300)
    private String tema;

    @Column(name = "num_preguntas")
    @Builder.Default
    private Integer numPreguntas = 10;

    @Column(length = 20)
    @Builder.Default
    private String dificultad = "media";

    @Column(columnDefinition = "TEXT")
    private String enfoque;

    @Column(name = "puntos_debiles", columnDefinition = "TEXT")
    private String puntosDebiles;

    @Column(length = 30)
    @Builder.Default
    private String estado = "pendiente"; // pendiente, procesando, completado, error

    @Column(name = "test_id")
    private Integer testId;

    @Column(name = "fecha_solicitud", updatable = false)
    @CreationTimestamp
    private LocalDateTime fechaSolicitud;

    @Column(name = "fecha_completado")
    private LocalDateTime fechaCompletado;

    // NOTA: ip_solicitud (tipo inet) no se mapea con JPA para evitar
    // incompatibilidades de tipo entre Hibernate 6 y el driver PostgreSQL.
    // La columna sigue existiendo en la BD pero se gestiona directamente
    // por n8n o por SQL nativo si fuera necesario en el futuro.
}
