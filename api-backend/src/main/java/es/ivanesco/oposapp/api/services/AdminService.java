package es.ivanesco.oposapp.api.services;

import es.ivanesco.oposapp.api.dtos.AdminConfigRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class AdminService {

    private final OllamaService ollamaService;

    public String updateConfig(AdminConfigRequest request) {
        return "Configuración actualizada a: " + request.getModel();
    }

    public String getOllamaStatus() {
        return ollamaService.getStatus();
    }
}
