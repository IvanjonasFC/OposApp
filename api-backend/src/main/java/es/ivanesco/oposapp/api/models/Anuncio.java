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
@Table(name = "anuncios", schema = "tfg")
public class Anuncio {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(nullable = false, length = 200)
    private String titulo;

    @Column(name = "imagen_url", nullable = false, columnDefinition = "TEXT")
    private String imagenUrl;

    @Column(name = "enlace_destino", nullable = false, columnDefinition = "TEXT")
    private String enlace;

    @Builder.Default
    private Boolean activo = true;

    @Column(name = "impresiones")
    @Builder.Default
    private Integer impresiones = 0;

    @Column(name = "clics")
    @Builder.Default
    private Integer clics = 0;

    @Column(name = "fecha_inicio")
    private LocalDateTime fechaInicio;

    @Column(name = "fecha_fin")
    private LocalDateTime fechaFin;

    @CreationTimestamp
    @Column(name = "fecha_creacion", updatable = false)
    private LocalDateTime fechaCreacion;
}
