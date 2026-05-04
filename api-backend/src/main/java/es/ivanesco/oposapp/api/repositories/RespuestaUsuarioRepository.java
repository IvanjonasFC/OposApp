package es.ivanesco.oposapp.api.repositories;

import es.ivanesco.oposapp.api.models.RespuestaUsuario;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface RespuestaUsuarioRepository extends JpaRepository<RespuestaUsuario, Integer> {
    List<RespuestaUsuario> findBySesionId(Integer sesionId);
}
