package es.ivanesco.oposapp.api.dtos;

import lombok.Data;

@Data
public class AdminConfigRequest {
    private String model;
    private Double temperature;
    private Boolean stream;
}
