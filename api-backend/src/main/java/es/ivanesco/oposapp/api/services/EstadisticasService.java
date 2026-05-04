package es.ivanesco.oposapp.api.services;

import es.ivanesco.oposapp.api.models.EstadisticasUsuario;
import es.ivanesco.oposapp.api.models.SesionTest;
import es.ivanesco.oposapp.api.repositories.EstadisticasUsuarioRepository;
import es.ivanesco.oposapp.api.repositories.SesionTestRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class EstadisticasService {

    private final EstadisticasUsuarioRepository estadisticasRepository;
    private final SesionTestRepository sesionTestRepository;

    @Transactional(readOnly = true)
    public Map<String, Object> getEstadisticas(Integer usuarioId) {
        EstadisticasUsuario stats = estadisticasRepository.findById(usuarioId)
                .orElse(new EstadisticasUsuario());

        List<SesionTest> historial = sesionTestRepository
                .findByUsuarioIdOrderByFechaInicioDesc(usuarioId);

        List<Map<String, Object>> historialDetalle = historial.stream()
                .limit(50)
                .map(h -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("id", h.getId());
                    m.put("tema",      h.getTest() != null ? h.getTest().getTema()     : "Test Generado");
                    m.put("oposicion", h.getTest() != null ? h.getTest().getOposicion(): "");
                    double pct = h.getPuntuacionPorcentaje() != null
                            ? h.getPuntuacionPorcentaje().doubleValue() : 0.0;
                    m.put("nota", Math.round(pct / 10.0 * 10.0) / 10.0);
                    m.put("fecha", h.getFechaInicio() != null ? h.getFechaInicio().toString() : "");
                    return m;
                })
                .collect(Collectors.toList());

        // Vistas de BD — temas débiles y evolución 30 días
        List<Map<String, Object>> temasDebiles = estadisticasRepository.findTemasDebiles(usuarioId);
        List<Map<String, Object>> evolucion30d = estadisticasRepository.findEvolucion30Dias(usuarioId);

        Map<String, Object> resultado = new HashMap<>();
        resultado.put("testsCompletados",     stats.getTestsCompletados() != null     ? stats.getTestsCompletados()     : 0);
        resultado.put("preguntasRespondidas", stats.getPreguntasRespondidas() != null ? stats.getPreguntasRespondidas() : 0);
        resultado.put("preguntasCorrectas",   stats.getPreguntasCorrectas() != null   ? stats.getPreguntasCorrectas()   : 0);
        resultado.put("porcentajeAciertos",   stats.getPorcentajeAciertos() != null   ? stats.getPorcentajeAciertos()   : 0.0);
        resultado.put("diasConsecutivos",     stats.getDiasConsecutivos() != null     ? stats.getDiasConsecutivos()     : 0);
        resultado.put("historial",            historialDetalle);
        resultado.put("temasDebiles",         temasDebiles);
        resultado.put("evolucion30d",         evolucion30d);
        return resultado;
    }
}
