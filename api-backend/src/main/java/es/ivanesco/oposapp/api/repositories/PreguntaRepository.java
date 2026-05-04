package es.ivanesco.oposapp.api.repositories;

import es.ivanesco.oposapp.api.models.Pregunta;
import es.ivanesco.oposapp.api.models.SolicitudGeneracion;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface PreguntaRepository extends JpaRepository<Pregunta, Integer> {
    List<Pregunta> findBySolicitudId(Integer solicitudId);
    List<Pregunta> findByTestId(Integer testId);
    void deleteBySolicitudAndTestIdIsNull(SolicitudGeneracion solicitud);

    // Usado por AdminController.getStats() para contar preguntas generadas hoy
    long countByFechaCreacionAfter(LocalDateTime fecha);
}
