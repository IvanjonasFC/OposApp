package es.ivanesco.oposapp.api.services;

import es.ivanesco.oposapp.api.models.Convocatoria;
import es.ivanesco.oposapp.api.repositories.ConvocatoriaRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class BopaService {

    private final ConvocatoriaRepository repository;

    public Page<Convocatoria> getConvocatorias(Pageable pageable) {
        return repository.findAll(pageable);
    }

    public Page<Convocatoria> searchConvocatorias(String query, Pageable pageable) {
        // Sanitiza la query para tsquery: reemplaza espacios por " & " (AND)
        String tsQuery = query.trim().replaceAll("\\s+", " & ");
        return repository.fullTextSearch(tsQuery, pageable);
    }

    public Page<Convocatoria> getConvocatoriasGuardadas(Integer usuarioId, Pageable pageable) {
        return repository.findGuardadasByUsuarioId(usuarioId, pageable);
    }

    public void guardarConvocatoria(Integer usuarioId, Integer convocatoriaId) {
        repository.guardarConvocatoria(usuarioId, convocatoriaId);
    }

    public void eliminarConvocatoriaGuardada(Integer usuarioId, Integer convocatoriaId) {
        repository.eliminarGuardada(usuarioId, convocatoriaId);
    }
}
