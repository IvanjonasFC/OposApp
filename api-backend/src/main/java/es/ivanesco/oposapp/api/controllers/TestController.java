package es.ivanesco.oposapp.api.controllers;

import es.ivanesco.oposapp.api.dtos.RespuestaEnvioDto;
import es.ivanesco.oposapp.api.dtos.SesionTestDto;
import es.ivanesco.oposapp.api.dtos.SolicitudGeneracionDto;
import es.ivanesco.oposapp.api.dtos.TestGenerateRequest;
import es.ivanesco.oposapp.api.models.Reporte;
import es.ivanesco.oposapp.api.models.SolicitudGeneracion;
import es.ivanesco.oposapp.api.models.Usuario;
import es.ivanesco.oposapp.api.repositories.ReporteRepository;
import es.ivanesco.oposapp.api.services.TestAsyncExecutor;
import es.ivanesco.oposapp.api.services.TestService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/tests")
@RequiredArgsConstructor
public class TestController {

    private final TestService testService;
    private final TestAsyncExecutor testAsyncExecutor;
    private final ReporteRepository reporteRepository;

    /** POST /api/tests/generate — crea solicitud y lanza Ollama async */
    @PostMapping("/generate")
    public ResponseEntity<SolicitudGeneracionDto> generarTest(
            @Valid @RequestBody TestGenerateRequest request,
            @AuthenticationPrincipal Usuario usuario) {
        SolicitudGeneracion solicitud = testService.iniciarGeneracion(request, usuario);
        testAsyncExecutor.procesarTest(solicitud.getId());
        return ResponseEntity.ok(SolicitudGeneracionDto.from(solicitud));
    }

    /** GET /api/tests/mis-solicitudes — historial del usuario para la pestaña Tests */
    @GetMapping("/mis-solicitudes")
    public ResponseEntity<List<SolicitudGeneracionDto>> getMisSolicitudes(
            @AuthenticationPrincipal Usuario usuario) {
        return ResponseEntity.ok(testService.getMisSolicitudes(usuario));
    }

    /** GET /api/tests/solicitud/{id}/estado — polling de Flutter cada 3s */
    @GetMapping("/solicitud/{id}/estado")
    public ResponseEntity<Map<String, Object>> getEstadoSolicitud(
            @PathVariable Integer id,
            @AuthenticationPrincipal Usuario usuario) {
        return ResponseEntity.ok(testService.getStatus(id, usuario));
    }

    /** GET /api/tests/{id} — test completo con preguntas */
    @GetMapping("/{id}")
    public ResponseEntity<Map<String, Object>> getTest(
            @PathVariable Integer id,
            @AuthenticationPrincipal Usuario usuario) {
        return ResponseEntity.ok(testService.getTestCompleto(id, usuario));
    }

    /** PUT /api/tests/{id}/respuestas — evalúa y guarda la sesión */
    @PutMapping("/{id}/respuestas")
    public ResponseEntity<SesionTestDto> enviarRespuestas(
            @PathVariable Integer id,
            @Valid @RequestBody List<RespuestaEnvioDto> respuestas,
            @AuthenticationPrincipal Usuario usuario) {
        return ResponseEntity.ok(SesionTestDto.from(testService.evaluarRespuestas(id, respuestas, usuario)));
    }

    /** DELETE /api/tests/solicitud/{id} — elimina solicitud con error */
    @DeleteMapping("/solicitud/{id}")
    public ResponseEntity<Void> deleteSolicitud(
            @PathVariable Integer id,
            @AuthenticationPrincipal Usuario usuario) {
        testService.deleteSolicitud(id, usuario);
        return ResponseEntity.noContent().build();
    }

    /**
     * GET /api/tests/solicitud/{id}/reporte — devuelve el reporte IA de una solicitud.
     * Devuelve 404 si aún no se ha generado reporte para esta solicitud.
     */
    @GetMapping("/solicitud/{id}/reporte")
    public ResponseEntity<Map<String, Object>> getReporte(
            @PathVariable Integer id,
            @AuthenticationPrincipal Usuario usuario) {
        return reporteRepository.findBySolicitudId(id)
                .map(r -> {
                    Map<String, Object> body = new java.util.LinkedHashMap<>();
                    body.put("id", r.getId());
                    body.put("solicitudId", r.getSolicitudId());
                    body.put("nota", r.getNota());
                    body.put("consejoIa", r.getConsejoIa());
                    return ResponseEntity.ok(body);
                })
                .orElse(ResponseEntity.notFound().build());
    }
}
