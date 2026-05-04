package es.ivanesco.oposapp.api.services;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

/**
 * Servicio de comunicación con el servidor de IA local (Ollama).
 *
 * <p>Encapsula las llamadas HTTP a {@code /api/generate} y {@code /api/tags},
 * gestionando automáticamente las diferencias entre familias de modelos:
 * <ul>
 *   <li><b>qwen2.5-coder</b> (FREE): {@code format="json"} activo, temperatura 0.3.
 *       Devuelve JSON envuelto en {@code {"preguntas":[...]}}.</li>
 *   <li><b>qwen3</b> (PREMIUM): {@code think=false} a nivel raíz, sin {@code format}.
 *       Devuelve un array JSON limpio {@code [...]}. Temperatura 0.2.</li>
 * </ul>
 *
 * <p>La detección de familia se hace por el nombre del modelo ({@link #esQwen3}).
 * Los modelos se configuran en {@code application.yml} vía las propiedades
 * {@code ollama.model-free} y {@code ollama.model-premium}.
 */

import es.ivanesco.oposapp.api.dtos.OllamaPromptRequest;
import es.ivanesco.oposapp.api.dtos.OllamaResponseDto;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Servicio de comunicación con Ollama.
 *
 * Gestiona automáticamente las diferencias entre familias de modelos:
 *
 * qwen2.5-coder → format="json" | think=null
 * qwen3 → format=null | think=false (think a nivel raíz)
 *
 * Detección: si el nombre del modelo contiene "qwen3" → familia qwen3.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class OllamaService {

    private final RestTemplate restTemplate;

    @Value("${ollama.url}")
    private String ollamaUrl;

    /** Devuelve la URL base de Ollama (leida de configuracion, sin hardcodear). */
    public String getUrl() { return ollamaUrl; }

    @Value("${ollama.model-free:qwen2.5:3b-instruct}")
    private String modeloFree;

    @Value("${ollama.model-premium:qwen-claude-64k:latest}")
    private String modeloPremium;

    public String getModeloFree() {
        return modeloFree;
    }

    public String getModeloPremium() {
        return modeloPremium;
    }

    // ─── Detección de familia ──────────────────────────────────────────────

    /**
     * Devuelve true si el modelo pertenece a la familia Qwen3 (thinking models).
     */
    private boolean esQwen3(String model) {
        return model != null && model.toLowerCase().contains("qwen3");
    }

    // ─── Envío de prompt ──────────────────────────────────────────────────

    /**
     * Envía un prompt al modelo indicado y devuelve la respuesta como String.
     *
     * Comportamiento por familia:
     * - qwen2.5-coder: format=null, think=null, temperature=0.3
     * (format=json forzaba al modelo a devolver 1 solo objeto — sin él devuelve el
     * array completo)
     * - qwen3: format=null, think=false, temperature=0.2
     */
    public String sendPrompt(String model, String prompt) {
        boolean isQwen3 = esQwen3(model);

        OllamaPromptRequest.OllamaOptions opts = OllamaPromptRequest.OllamaOptions.builder()
                .temperature(isQwen3 ? 0.2 : 0.3)
                .num_predict(3500)
                .build();

        OllamaPromptRequest requestBody = OllamaPromptRequest.builder()
                .model(model)
                .prompt(prompt)
                .stream(false)
                .format(null) // sin format=json para ambos
                .think(isQwen3 ? Boolean.FALSE : null) // qwen3: think=false raiz
                .options(opts)
                .build();

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        HttpEntity<OllamaPromptRequest> request = new HttpEntity<>(requestBody, headers);

        log.info("Ollama → model={} qwen3={} url={}", model, isQwen3, ollamaUrl);
        try {
            ResponseEntity<OllamaResponseDto> response = restTemplate.postForEntity(
                    ollamaUrl + "/api/generate", request, OllamaResponseDto.class);
            if (response.getBody() != null) {
                String resp = response.getBody().getResponse();
                log.debug("Ollama raw (primeros 200): {}",
                        resp != null ? resp.substring(0, Math.min(200, resp.length())) : "null");
                return resp;
            }
        } catch (Exception e) {
            log.error("Error conectando con Ollama (url={}): {}", ollamaUrl, e.getMessage());
            throw new RuntimeException("Error de comunicación con Ollama: " + e.getMessage());
        }
        return null;
    }

    // ─── Estado ──────────────────────────────────────────────────────────

    public String getStatus() {
        try {
            return restTemplate.getForEntity(ollamaUrl + "/api/tags", String.class).getBody();
        } catch (Exception e) {
            throw new RuntimeException("Error verificando estado de Ollama: " + e.getMessage());
        }
    }

    public boolean isOnline() {
        try {
            restTemplate.getForEntity(ollamaUrl + "/api/tags", String.class);
            return true;
        } catch (Exception e) {
            log.warn("Ollama no responde: {}", e.getMessage());
            return false;
        }
    }
}
