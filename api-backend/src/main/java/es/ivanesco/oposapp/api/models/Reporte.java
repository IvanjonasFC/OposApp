package es.ivanesco.oposapp.api.models;

import jakarta.persistence.*;
import lombok.*;
import java.math.BigDecimal;

/**
 * Tabla: tfg.reportes
 * Almacena el consejo de IA y la nota asociados a una solicitud de generación.
 * Se crea automáticamente cuando el usuario completa un test.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "reportes", schema = "tfg")
public class Reporte {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "consejo_ia", columnDefinition = "TEXT")
    private String consejoIa;

    @Column(nullable = false, precision = 5, scale = 2)
    private BigDecimal nota;

    @Column(name = "solicitud_id", nullable = false)
    private Integer solicitudId;
}
