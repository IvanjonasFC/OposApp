package es.ivanesco.oposapp.api.models;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

/**
 * Registra cada solicitud de baja (RGPD Art. 17 — Derecho al olvido).
 * La eliminación física del usuario se ejecuta 48 h después mediante
 * el job programado en UserService.cleanUpDeletedUsers().
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "solicitudes_baja", schema = "tfg")
public class SolicitudBaja {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "usuario_id", nullable = false)
    private Usuario usuario;

    @Column(length = 500)
    private String motivo;

    /** pendiente → completado (tras borrado físico a las 48 h) */
    @Column(length = 20)
    @Builder.Default
    private String estado = "pendiente";

    @Column(name = "fecha_solicitud", updatable = false)
    @CreationTimestamp
    private LocalDateTime fechaSolicitud;

    @Column(name = "fecha_ejecucion")
    private LocalDateTime fechaEjecucion;
}
