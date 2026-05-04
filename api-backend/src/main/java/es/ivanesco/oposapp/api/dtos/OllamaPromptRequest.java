package es.ivanesco.oposapp.api.dtos;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.Builder;
import lombok.Data;

/**
 * DTO para las llamadas a la API de Ollama (/api/generate).
 *
 * Soporta dos familias de modelos con comportamiento distinto:
 *
 *  - qwen2.5-coder  → format="json" activo   | think=null (no soportado)
 *  - qwen3          → format=null (desactivado) | think=false (root-level)
 *
 * Los campos null se omiten en la serialización JSON (@JsonInclude).
 */
@Data
@Builder
@JsonInclude(JsonInclude.Include.NON_NULL)
public class OllamaPromptRequest {

    private String  model;
    private String  prompt;

    @Builder.Default
    private boolean stream = false;

    /**
     * Para qwen2.5-coder: "json" → fuerza salida JSON válida.
     * Para qwen3: null → no usar format (interfiere con la generación de arrays).
     */
    private String format;

    /**
     * Solo para modelos qwen3: false → desactiva el modo thinking.
     * null para qwen2.5-coder (el campo no se serializa).
     * IMPORTANTE: debe ir a nivel raíz del request, no dentro de options.
     */
    private Boolean think;

    /**
     * Opciones de generación: temperatura, longitud máxima, etc.
     */
    private OllamaOptions options;

    @Data
    @Builder
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class OllamaOptions {
        @Builder.Default
        private double  temperature = 0.3;
        @Builder.Default
        private int     num_predict = 5000;
        private Double  top_p;
        private Integer top_k;
        private Double  repeat_penalty;
    }
}
