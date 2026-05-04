package es.ivanesco.oposapp.api.controllers;

import es.ivanesco.oposapp.api.models.Anuncio;
import es.ivanesco.oposapp.api.models.Role;
import es.ivanesco.oposapp.api.models.Usuario;
import es.ivanesco.oposapp.api.repositories.AnuncioRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.Map;

/**
 * Endpoints de publicidad interna (RF-21, RF-22, RF-23).
 * Solo se sirven anuncios a usuarios con rol USER (gratuitos).
 * Los PREMIUM y ADMIN nunca reciben publicidad.
 *
 * GET  /api/ads/random    → anuncio activo aleatorio (solo para USER)
 * POST /api/ads/{id}/click → registra un clic y devuelve la URL de destino
 */
@RestController
@RequestMapping("/api/ads")
@RequiredArgsConstructor
public class AdsController {

    private final AnuncioRepository anuncioRepository;

    /**
     * Devuelve un anuncio activo aleatorio.
     * Si el usuario es PREMIUM o ADMIN devuelve 204 No Content → Flutter no muestra banner.
     * También filtra por fecha_inicio/fecha_fin si están definidas.
     */
    @GetMapping("/random")
    public ResponseEntity<Anuncio> getRandomAd(
            @AuthenticationPrincipal Usuario usuario) {

        // Los usuarios de pago no ven publicidad
        if (usuario != null && usuario.getRol() != Role.USER) {
            return ResponseEntity.noContent().build();
        }

        return anuncioRepository.findRandomActiveAd(LocalDateTime.now())
                .map(ad -> {
                    // Registrar impresión
                    ad.setImpresiones(ad.getImpresiones() + 1);
                    anuncioRepository.save(ad);
                    return ResponseEntity.ok(ad);
                })
                .orElse(ResponseEntity.noContent().build());
    }

    /**
     * Registra un clic en el anuncio y devuelve la URL de destino para que
     * Flutter la abra con url_launcher (RF-23).
     */
    @PostMapping("/{id}/click")
    public ResponseEntity<Map<String, String>> registerClick(
            @PathVariable Integer id) {

        return anuncioRepository.findById(id)
                .map(ad -> {
                    ad.setClics(ad.getClics() + 1);
                    anuncioRepository.save(ad);
                    return ResponseEntity.ok(Map.of("url", ad.getEnlace()));
                })
                .orElse(ResponseEntity.notFound().build());
    }
}
