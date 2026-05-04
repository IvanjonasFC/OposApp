package es.ivanesco.oposapp.api.models;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "convocatorias", schema = "tfg")
public class Convocatoria {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "bopa_numero", nullable = false, length = 100)
    private String bopaNumero;

    @Column(name = "fecha_publicacion", nullable = false)
    private LocalDate fechaPublicacion;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String titulo;

    @Column(length = 300)
    private String organismo;

    @Column(length = 100)
    private String categoria;

    @Column(name = "num_plazas")
    @Builder.Default
    private Integer numPlazas = 0;

    @Column(name = "url_bopa", nullable = false, columnDefinition = "TEXT")
    private String urlBopa;

    @Column(name = "texto_completo", columnDefinition = "TEXT")
    private String textoCompleto;

    @Column(name = "fecha_scraping")
    @Builder.Default
    private LocalDateTime fechaScraping = LocalDateTime.now();

    @Builder.Default
    private Boolean activo = true;
}
