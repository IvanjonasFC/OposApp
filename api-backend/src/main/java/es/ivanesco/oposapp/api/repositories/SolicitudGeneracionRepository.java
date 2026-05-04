package es.ivanesco.oposapp.api.repositories;

import es.ivanesco.oposapp.api.models.SolicitudGeneracion;
import es.ivanesco.oposapp.api.models.Usuario;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SolicitudGeneracionRepository extends JpaRepository<SolicitudGeneracion, Integer> {
    List<SolicitudGeneracion> findByUsuarioIdOrderByFechaSolicitudDesc(Integer usuarioId);
    List<SolicitudGeneracion> findByUsuarioOrderByFechaSolicitudDesc(Usuario usuario);
    long countByEstado(String estado);
}
