package es.ivanesco.oposapp.api.services;

/**
 * Servicio central de la lógica de generación y evaluación de tests.
 *
 * <p>Responsabilidades:
 * <ul>
 *   <li>Crear solicitudes de generación ({@link #iniciarGeneracion}) y lanzarlas de forma asíncrona.</li>
 *   <li>Construir el prompt para Ollama y parsear la respuesta JSON con las preguntas.</li>
 *   <li>Evaluar las respuestas del usuario y calcular la puntuación ({@link #evaluarRespuestas}).</li>
 *   <li>Actualizar {@code estadisticas_usuario} tras cada sesión completada.</li>
 * </ul>
 *
 * <p>Patrón de generación asíncrona:
 * <ol>
 *   <li>El controlador llama a {@code iniciarGeneracion} → crea la solicitud en BD (estado: "pendiente").</li>
 *   <li>{@link TestAsyncExecutor} ejecuta {@code procesarTest} en un hilo separado vía {@code @Async}.</li>
 *   <li>Flutter hace polling a {@code /api/tests/solicitud/{id}/estado} cada 3 segundos.</li>
 *   <li>Al pasar a "completado", Flutter descarga el test con {@code /api/tests/{id}}.</li>
 * </ol>
 */

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import es.ivanesco.oposapp.api.dtos.RespuestaEnvioDto;
import es.ivanesco.oposapp.api.dtos.SolicitudGeneracionDto;
import es.ivanesco.oposapp.api.dtos.TestGenerateRequest;
import es.ivanesco.oposapp.api.models.*;
import es.ivanesco.oposapp.api.repositories.*;
import lombok.RequiredArgsConstructor;
import jakarta.persistence.EntityNotFoundException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.*;

@Service
@RequiredArgsConstructor
@Slf4j
public class TestService {

    private final SolicitudGeneracionRepository solicitudRepository;
    private final PreguntaRepository preguntaRepository;
    private final SesionTestRepository sesionTestRepository;
    private final RespuestaUsuarioRepository respuestaUsuarioRepository;
    private final EstadisticasUsuarioRepository estadisticasRepository;
    private final TestRepository testRepository;
    private final UsuarioRepository usuarioRepository;
    private final OllamaService ollamaService;
    private final ObjectMapper objectMapper;
    private final AuditService auditService;
    private final NotificacionService notificacionService;

    @Transactional
    public SolicitudGeneracion iniciarGeneracion(TestGenerateRequest request, Usuario usuarioDetached) {
        // Re-fetch para tener entidad managed
        Usuario usuario = usuarioRepository.findById(usuarioDetached.getId())
                .orElseThrow(() -> new EntityNotFoundException("Usuario no encontrado: " + usuarioDetached.getId()));
        SolicitudGeneracion solicitud = SolicitudGeneracion.builder()
                .usuario(usuario).tema(request.getTema()).oposicion(request.getOposicion())
                .dificultad(request.getDificultad()).numPreguntas(request.getNumPreguntas())
                .estado("pendiente").build();
        return solicitudRepository.save(solicitud);
    }

    /** Devuelve las solicitudes del usuario ordenadas por fecha desc — para la UI de Tests.
     *  Enriquece cada DTO con vecesRealizado y ultimaNota consultando sesiones_test. */
    @Transactional(readOnly = true)
    public List<SolicitudGeneracionDto> getMisSolicitudes(Usuario usuarioDetached) {
        Integer usuarioId = usuarioDetached.getId();
        // findById en vez de getReferenceById para evitar proxy sin sesión
        Usuario usuario = usuarioRepository.findById(usuarioId)
                .orElseThrow(() -> new EntityNotFoundException("Usuario no encontrado"));
        List<SolicitudGeneracion> solicitudes = solicitudRepository
                .findByUsuarioOrderByFechaSolicitudDesc(usuario);

        List<SolicitudGeneracionDto> result = new ArrayList<>();
        for (SolicitudGeneracion s : solicitudes) {
            if (s.getTestId() == null || !"completado".equals(s.getEstado())) {
                result.add(SolicitudGeneracionDto.from(s));
                continue;
            }
            int veces = sesionTestRepository.countCompletadasByTestIdAndUsuarioId(s.getTestId(), usuarioId);
            Double ultimaNota = null;
            List<SesionTest> ultimas = sesionTestRepository
                    .findUltimaCompletadaByTestIdAndUsuarioId(s.getTestId(), usuarioId);
            if (!ultimas.isEmpty() && ultimas.get(0).getPuntuacionPorcentaje() != null) {
                ultimaNota = ultimas.get(0).getPuntuacionPorcentaje().doubleValue();
            }
            result.add(SolicitudGeneracionDto.from(s, veces, ultimaNota));
        }
        return result;
    }

    @Transactional
    public void procesarTest(Integer solicitudId) {
        SolicitudGeneracion solicitud = solicitudRepository.findById(solicitudId).orElseThrow();
        solicitud.setEstado("procesando");
        solicitudRepository.save(solicitud);

        auditService.registrar("TEST_GENERADO", "solicitudes_generacion",
                solicitud.getUsuario().getId(), null,
                "solicitudId=" + solicitudId + " tema=" + solicitud.getTema() + " num=" + solicitud.getNumPreguntas());

        try {
            boolean esPremium = solicitud.getUsuario().getTipoSuscripcion() != null
                    && solicitud.getUsuario().getTipoSuscripcion().equalsIgnoreCase("PREMIUM");
            String modeloIa = esPremium ? ollamaService.getModeloPremium() : ollamaService.getModeloFree();
            log.info("Usando modelo Ollama: {} para solicitudId={}", modeloIa, solicitudId);

            String prompt = String.format(
                // ── PROMPT MEJORADO v2 ──────────────────────────────────────────────────────
                // Cambios respecto a v1:
                //  · Instrucción explícita de comenzar con '[' (crítico para qwen3 sin format=json)
                //  · Restricción de contenido específica al tema (evita divagaciones)
                //  · Aclaración de que 'correcta' es UNA SOLA letra sin punto ni paréntesis
                //  · Número de preguntas reforzado dos veces (inicio y fin del prompt)
                // ────────────────────────────────────────────────────────────────────────────
                "Eres un experto en preparación de oposiciones del sector público español. " +
                "Tu única tarea es generar exactamente %d preguntas de tipo test en español " +
                "sobre el tema '%s' para la oposición '%s', nivel de dificultad '%s'. " +
                "REGLAS OBLIGATORIAS: " +
                "1. Responde ÚNICA Y EXCLUSIVAMENTE con un array JSON válido que empiece con [ y termine con ]. " +
                "2. Sin texto previo, sin texto posterior, sin bloques markdown, sin etiquetas <think>. " +
                "3. Las preguntas deben ser precisas, correctas y específicas del tema indicado. " +
                "4. El array debe contener EXACTAMENTE %d elementos. " +
                "Formato de cada elemento (sigue este ejemplo al pie de la letra): " +
                "{\"enunciado\":\"¿Cuál es el artículo de la Constitución Española que reconoce el derecho a la igualdad?\", " +
                "\"opciones\":[\"A) Artículo 10\",\"B) Artículo 14\",\"C) Artículo 20\",\"D) Artículo 25\"], " +
                "\"correcta\":\"B\", " +
                "\"explicacion\":\"El Artículo 14 establece que los españoles son iguales ante la ley sin discriminación por nacimiento, raza, sexo, religión, opinión o cualquier otra circunstancia.\"}",
                solicitud.getNumPreguntas(), solicitud.getTema(),
                solicitud.getOposicion(), solicitud.getDificultad(),
                solicitud.getNumPreguntas());

            String respuestaRaw = ollamaService.sendPrompt(modeloIa, prompt);
            if (respuestaRaw == null || respuestaRaw.isBlank()) throw new RuntimeException("Ollama devolvió respuesta vacía");
            log.info("Raw Ollama response (primeros 500 chars): {}", respuestaRaw.substring(0, Math.min(500, respuestaRaw.length())));

            List<Map<String, Object>> preguntas = extraerPreguntas(respuestaRaw);
            if (preguntas == null || preguntas.isEmpty()) throw new RuntimeException("No se extrajeron preguntas");

            TestEntity test = TestEntity.builder()
                    .titulo(solicitud.getTema() + " — " + solicitud.getDificultad())
                    .oposicion(solicitud.getOposicion()).tema(solicitud.getTema())
                    .dificultad(solicitud.getDificultad()).numPreguntas(preguntas.size())
                    .createdBy(solicitud.getUsuario()).build();
            test = testRepository.save(test);

            List<Pregunta> entidades = new ArrayList<>();
            for (Map<String, Object> p : preguntas) {
                List<String> opciones = extraerOpciones(p.get("opciones"));
                String correctaRaw = p.get("correcta") != null ? p.get("correcta").toString().trim() : "A";
                String correcta = correctaRaw.isEmpty() ? "A" : String.valueOf(correctaRaw.charAt(0)).toUpperCase();
                entidades.add(Pregunta.builder()
                        .testId(test.getId()).solicitud(solicitud)
                        .textoPregunta(strVal(p, "enunciado"))
                        .opcionA(opciones.size() > 0 ? opciones.get(0) : "")
                        .opcionB(opciones.size() > 1 ? opciones.get(1) : "")
                        .opcionC(opciones.size() > 2 ? opciones.get(2) : "")
                        .opcionD(opciones.size() > 3 ? opciones.get(3) : "")
                        .respuestaCorrecta(correcta)
                        .explicacion(strVal(p, "explicacion"))
                        .tema(solicitud.getTema()).oposicion(solicitud.getOposicion())
                        .dificultad(solicitud.getDificultad()).build());
            }
            preguntaRepository.saveAll(entidades);
            solicitud.setTestId(test.getId()); solicitud.setEstado("completado");
            solicitud.setFechaCompletado(LocalDateTime.now());
            solicitudRepository.save(solicitud);
            auditService.registrar("TEST_COMPLETADO", "tests",
                    solicitud.getUsuario().getId(), null,
                    "testId=" + test.getId() + " preguntas=" + entidades.size());
            notificacionService.crear(
                    solicitud.getUsuario().getId(),
                    "test_completado",
                    "Test listo: " + solicitud.getTema(),
                    solicitud.getNumPreguntas() + " preguntas · " + solicitud.getDificultad() + " · " + solicitud.getOposicion());
            log.info("Test OK — solicitudId={} testId={} preguntas={}", solicitudId, test.getId(), entidades.size());
        } catch (Exception e) {
            log.error("Error procesarTest solicitudId={}: {}", solicitudId, e.getMessage(), e);
            solicitud.setEstado("error"); solicitudRepository.save(solicitud);
            notificacionService.crear(
                    solicitud.getUsuario().getId(),
                    "sistema",
                    "Error al generar: " + solicitud.getTema(),
                    "El test no pudo generarse. Intenta de nuevo.");
            auditService.registrar("TEST_ERROR", "solicitudes_generacion",
                    solicitud.getUsuario().getId(), null,
                    "solicitudId=" + solicitudId + " error=" + e.getMessage());
        }
    }

    private String strVal(Map<String, Object> map, String key) {
        Object v = map.get(key);
        return v != null ? v.toString() : "";
    }

    /** Extrae la lista de opciones de forma robusta.
     *  Ollama puede devolver: List<String>, List<Object>, o un String separado por comas. */
    @SuppressWarnings("unchecked")
    private List<String> extraerOpciones(Object opcionesObj) {
        if (opcionesObj instanceof List) {
            List<?> raw = (List<?>) opcionesObj;
            List<String> result = new ArrayList<>();
            for (Object item : raw) result.add(item != null ? item.toString() : "");
            return result;
        }
        if (opcionesObj instanceof String) {
            // Fallback: "A) texto, B) texto, C) texto, D) texto"
            return Arrays.asList(opcionesObj.toString().split(",\\s*"));
        }
        return new ArrayList<>();
    }

    /**
     * Parser robusto usando JsonNode.
     *
     * Soporta dos formatos que devuelve qwen2.5-coder:
     *
     * FORMATO A (correcto) — array de objetos completos:
     *   [{"enunciado":"...","opciones":["A)...","B)...","C)...","D)..."],"correcta":"B","explicacion":"..."}]
     *
     * FORMATO B (defectuoso, frecuente con 14b) — opciones como strings sueltos tras el objeto:
     *   [{"enunciado":"...","correcta":"B","explicacion":"..."},"A) texto","B) texto","C) texto","D) texto", ...]
     *
     * Para el formato B, acumulamos los strings que siguen al objeto y los asignamos como opciones.
     */
    private List<Map<String, Object>> extraerPreguntas(String raw) throws Exception {
        String texto = raw.trim();

        // Quitar bloques markdown ```json ... ```
        if (texto.contains("```")) {
            int ini = texto.indexOf('[', texto.indexOf("```"));
            int fin = texto.lastIndexOf(']');
            if (ini != -1 && fin > ini) texto = texto.substring(ini, fin + 1);
            else texto = texto.replaceAll("```[a-zA-Z]*", "").replaceAll("```", "").trim();
        }

        String jsonArrayStr = extraerArrayJson(texto);
        if (jsonArrayStr == null) throw new RuntimeException(
                "No se encontró array JSON en: " + texto.substring(0, Math.min(200, texto.length())));

        JsonNode root = objectMapper.readTree(jsonArrayStr);
        if (!root.isArray()) throw new RuntimeException("El JSON raíz no es un array");

        List<Map<String, Object>> resultado = new ArrayList<>();
        Map<String, Object> pendiente = null;   // último objeto sin opciones asignadas
        List<String> opcionesPendientes = new ArrayList<>();

        for (JsonNode nodo : root) {
            if (nodo.isObject()) {
                // Antes de procesar el nuevo objeto, cerrar el pendiente anterior
                if (pendiente != null) {
                    asignarOpcionesSiVacias(pendiente, opcionesPendientes);
                    resultado.add(pendiente);
                }
                pendiente = objectMapper.convertValue(nodo, new TypeReference<Map<String, Object>>() {});
                opcionesPendientes = new ArrayList<>();

            } else if (nodo.isTextual()) {
                String txt = nodo.asText().trim();
                // Si parece una opción (empieza por A) B) C) D) o a) b) c) d))
                // la recogemos para el objeto pendiente. Si no, la ignoramos.
                if (txt.matches("(?i)^[A-D][).]\\s*.+")) {
                    opcionesPendientes.add(txt);
                } else {
                    log.warn("Ignorando string en array de preguntas: {}",
                            txt.substring(0, Math.min(60, txt.length())));
                }
            }
            // números, booleans → ignorar
        }

        // Cerrar el último objeto pendiente
        if (pendiente != null) {
            asignarOpcionesSiVacias(pendiente, opcionesPendientes);
            resultado.add(pendiente);
        }

        return resultado;
    }

    /**
     * Si el objeto no tiene campo "opciones" (o está vacío) y hay opciones pendientes
     * recogidas como strings sueltos, las asigna.
     */
    @SuppressWarnings("unchecked")
    private void asignarOpcionesSiVacias(Map<String, Object> pregunta, List<String> opciones) {
        if (opciones.isEmpty()) return;
        Object existentes = pregunta.get("opciones");
        boolean vacio = (existentes == null)
                || (existentes instanceof List && ((List<?>) existentes).isEmpty());
        if (vacio) {
            pregunta.put("opciones", new ArrayList<>(opciones));
            log.debug("Asignadas {} opciones sueltas al objeto: {}", opciones.size(),
                    pregunta.get("enunciado") != null
                            ? pregunta.get("enunciado").toString().substring(
                                    0, Math.min(50, pregunta.get("enunciado").toString().length()))
                            : "?");
        }
    }

    /** Extrae la primera subcadena [...] válida del texto */
    private String extraerArrayJson(String texto) {
        // Caso 1: empieza directamente con [
        if (texto.startsWith("[")) return texto;

        // Caso 2: objeto JSON — puede ser wrapper o pregunta individual
        if (texto.startsWith("{")) {
            try {
                JsonNode wrapper = objectMapper.readTree(texto);

                // Caso 2a: es una pregunta individual (tiene "enunciado" o "pregunta")
                // → envolverla en array
                if (wrapper.has("enunciado") || wrapper.has("pregunta") || wrapper.has("question")) {
                    log.info("Ollama devolvió una sola pregunta como objeto → envolviendo en array");
                    return "[" + texto + "]";
                }

                // Caso 2b: objeto wrapper {"preguntas": [...]} o similar
                // Buscar el campo que contenga el array — primero por nombres conocidos
                for (String campo : new String[]{"preguntas", "Preguntas", "pregunta", "Pregunta",
                        "questions", "Questions", "response", "content", "message",
                        "text", "output", "data", "items", "results", "test"}) {
                    JsonNode val = wrapper.get(campo);
                    if (val == null) continue;
                    if (val.isArray()) return val.toString();
                    if (val.isTextual()) {
                        String inner = val.asText().trim();
                        if (inner.startsWith("[")) return inner;
                        String sub = extraerArrayJson(inner);
                        if (sub != null) return sub;
                    }
                }
                // Fallback: buscar CUALQUIER campo que contenga un array de objetos JSON
                // (ignorar arrays de strings como "opciones")
                var fields = wrapper.fields();
                while (fields.hasNext()) {
                    var entry = fields.next();
                    if (entry.getValue().isArray() && entry.getValue().size() > 0
                            && entry.getValue().get(0).isObject()) {
                        log.info("Wrapper JSON: campo '{}' contiene array de {} objetos", entry.getKey(), entry.getValue().size());
                        return entry.getValue().toString();
                    }
                }
            } catch (Exception ignored) {}
        }

        // Caso 3: array embebido en texto libre — buscar [ balanceado
        int depth = 0;
        int start = -1;
        for (int i = 0; i < texto.length(); i++) {
            char c = texto.charAt(i);
            if (c == '[') { if (depth == 0) start = i; depth++; }
            else if (c == ']') { depth--; if (depth == 0 && start != -1) return texto.substring(start, i + 1); }
        }
        return null;
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getStatus(Integer solicitudId, Usuario usuario) {
        SolicitudGeneracion solicitud = solicitudRepository.findById(solicitudId)
                .orElseThrow(() -> new NoSuchElementException("Solicitud no encontrada: " + solicitudId));
        if (!solicitud.getUsuario().getId().equals(usuario.getId())) throw new SecurityException("Sin permiso");
        Map<String, Object> r = new java.util.LinkedHashMap<>();
        r.put("solicitudId", solicitud.getId()); r.put("estado", solicitud.getEstado());
        r.put("testId", solicitud.getTestId()); r.put("fechaCompletado", solicitud.getFechaCompletado());
        return r;
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getTestCompleto(Integer testId, Usuario usuario) {
        TestEntity test = testRepository.findById(testId)
                .orElseThrow(() -> new NoSuchElementException("Test no encontrado: " + testId));
        if (!test.getCreatedBy().getId().equals(usuario.getId())) throw new SecurityException("Sin permiso");
        List<Pregunta> preguntas = preguntaRepository.findByTestId(testId);
        Map<String, Object> r = new java.util.LinkedHashMap<>();
        r.put("testId", test.getId()); r.put("titulo", test.getTitulo()); r.put("oposicion", test.getOposicion());
        r.put("tema", test.getTema()); r.put("dificultad", test.getDificultad());
        r.put("numPreguntas", test.getNumPreguntas()); r.put("fechaCreacion", test.getFechaCreacion());
        r.put("preguntas", preguntas);
        return r;
    }

    @Transactional
    public SesionTest evaluarRespuestas(Integer testId, List<RespuestaEnvioDto> respuestasDto, Usuario usuarioDetached) {
        // ⚠️ FIX: re-fetch del usuario para que Hibernate no lo trate como "detached entity"
        // El objeto que llega de @AuthenticationPrincipal está fuera del contexto de persistencia actual
        Usuario usuario = usuarioRepository.findById(usuarioDetached.getId())
                .orElseThrow(() -> new EntityNotFoundException("Usuario no encontrado: " + usuarioDetached.getId()));

        TestEntity test = testRepository.findById(testId)
                .orElseThrow(() -> new NoSuchElementException("Test no encontrado: " + testId));
        SesionTest sesion = SesionTest.builder().usuario(usuario).test(test)
                .totalPreguntas(respuestasDto.size()).estado("en_progreso").completado(false).build();
        sesion = sesionTestRepository.save(sesion);
        int correctas = 0, incorrectas = 0, tiempoTotal = 0;
        List<RespuestaUsuario> entidades = new ArrayList<>();
        for (RespuestaEnvioDto dto : respuestasDto) {
            Pregunta p = preguntaRepository.findById(dto.getPreguntaId())
                    .orElseThrow(() -> new NoSuchElementException("Pregunta no encontrada: " + dto.getPreguntaId()));
            boolean esCorrecta = p.getRespuestaCorrecta().equalsIgnoreCase(dto.getRespuestaDada().trim());
            if (esCorrecta) correctas++; else incorrectas++;
            tiempoTotal += dto.getTiempoRespuesta();
            entidades.add(RespuestaUsuario.builder().sesion(sesion).pregunta(p)
                    .respuestaSeleccionada(dto.getRespuestaDada().toUpperCase())
                    .esCorrecta(esCorrecta).tiempoRespuesta(dto.getTiempoRespuesta()).build());
        }
        respuestaUsuarioRepository.saveAll(entidades);
        BigDecimal pct = respuestasDto.isEmpty() ? BigDecimal.ZERO :
                BigDecimal.valueOf(correctas * 100.0 / respuestasDto.size()).setScale(2, RoundingMode.HALF_UP);
        sesion.setPreguntasCorrectas(correctas); sesion.setPreguntasIncorrectas(incorrectas);
        sesion.setPuntuacionPorcentaje(pct); sesion.setTiempoTotal(tiempoTotal);
        sesion.setFechaFin(LocalDateTime.now()); sesion.setEstado("completada"); sesion.setCompletado(true);
        sesion = sesionTestRepository.save(sesion);
        actualizarEstadisticas(usuario, correctas, incorrectas, tiempoTotal);
        auditService.registrar("TEST_EVALUADO", "sesiones_test",
                usuario.getId(), null,
                "testId=" + testId + " correctas=" + correctas + " pct=" + pct);
        return sesion;
    }

    @Transactional
    public void deleteSolicitud(Integer solicitudId, Usuario usuario) {
        SolicitudGeneracion solicitud = solicitudRepository.findById(solicitudId)
                .orElseThrow(() -> new NoSuchElementException("Solicitud no encontrada: " + solicitudId));
        if (!solicitud.getUsuario().getId().equals(usuario.getId())) throw new SecurityException("Sin permiso");
        // Solo permitir borrar las que están en error o pendiente sin test generado
        if ("completado".equals(solicitud.getEstado()) && solicitud.getTestId() != null) {
            throw new IllegalStateException("No se puede eliminar un test completado");
        }
        // Borrar preguntas huérfanas asociadas a esta solicitud (sin test_id)
        preguntaRepository.deleteBySolicitudAndTestIdIsNull(solicitud);
        solicitudRepository.delete(solicitud);
    }

    @Transactional
    public void actualizarEstadisticas(Usuario usuarioDetached, int nuevasCorrectas, int nuevasIncorrectas, int tiempoSeg) {
        // ⚠️ FIX: re-fetch para tener entidad managed dentro de esta transacción
        Usuario usuario = usuarioRepository.findById(usuarioDetached.getId())
                .orElseThrow(() -> new EntityNotFoundException("Usuario no encontrado: " + usuarioDetached.getId()));

        EstadisticasUsuario stats = estadisticasRepository.findById(usuario.getId())
                .orElseGet(() -> EstadisticasUsuario.builder().usuario(usuario).build());
        int totalResp = stats.getPreguntasRespondidas() + nuevasCorrectas + nuevasIncorrectas;
        int totalCorr = stats.getPreguntasCorrectas() + nuevasCorrectas;
        double pct = totalResp == 0 ? 0.0 : (totalCorr * 100.0) / totalResp;
        stats.setTestsCompletados(stats.getTestsCompletados() + 1);
        stats.setPreguntasRespondidas(totalResp); stats.setPreguntasCorrectas(totalCorr);
        stats.setPreguntasIncorrectas(stats.getPreguntasIncorrectas() + nuevasIncorrectas);
        stats.setPorcentajeAciertos(pct);
        stats.setTiempoTotalEstudioMinutos(stats.getTiempoTotalEstudioMinutos() + tiempoSeg / 60);
        stats.setUltimaActividad(LocalDateTime.now()); stats.setUltimaActualizacion(LocalDateTime.now());
        estadisticasRepository.save(stats);
    }
}
