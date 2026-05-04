package es.ivanesco.oposapp.api.dtos;

import lombok.Data;

@Data
public class OllamaResponseDto {
    private String model;
    private String response;
    private boolean done;
}
