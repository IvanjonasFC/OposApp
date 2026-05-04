package es.ivanesco.oposapp.api.repositories;

import es.ivanesco.oposapp.api.models.SolicitudBaja;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SolicitudBajaRepository extends JpaRepository<SolicitudBaja, Integer> {
    List<SolicitudBaja> findByEstado(String estado);
}
