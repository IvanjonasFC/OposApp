package es.ivanesco.oposapp.api.repositories;

import es.ivanesco.oposapp.api.models.Reporte;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface ReporteRepository extends JpaRepository<Reporte, Integer> {

    /** Devuelve el reporte asociado a una solicitud concreta */
    Optional<Reporte> findBySolicitudId(Integer solicitudId);
}
