package es.ivanesco.oposapp.api.repositories;

import es.ivanesco.oposapp.api.models.TestEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface TestRepository extends JpaRepository<TestEntity, Integer> {
    List<TestEntity> findByCreatedByIdOrderByFechaCreacionDesc(Integer usuarioId);
}
