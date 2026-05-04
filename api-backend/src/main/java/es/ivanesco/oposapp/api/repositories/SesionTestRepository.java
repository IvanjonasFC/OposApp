package es.ivanesco.oposapp.api.repositories;

import es.ivanesco.oposapp.api.models.SesionTest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SesionTestRepository extends JpaRepository<SesionTest, Integer> {

    List<SesionTest> findByUsuarioIdOrderByFechaInicioDesc(Integer usuarioId);

    /** Cuántas sesiones completadas tiene un usuario para un testId concreto */
    @Query("SELECT COUNT(s) FROM SesionTest s WHERE s.test.id = :testId AND s.usuario.id = :usuarioId AND s.completado = true")
    int countCompletadasByTestIdAndUsuarioId(@Param("testId") Integer testId, @Param("usuarioId") Integer usuarioId);

    /** La sesión más reciente completada de un usuario para un testId */
    @Query("SELECT s FROM SesionTest s WHERE s.test.id = :testId AND s.usuario.id = :usuarioId AND s.completado = true ORDER BY s.fechaInicio DESC")
    List<SesionTest> findUltimaCompletadaByTestIdAndUsuarioId(@Param("testId") Integer testId, @Param("usuarioId") Integer usuarioId);
}
