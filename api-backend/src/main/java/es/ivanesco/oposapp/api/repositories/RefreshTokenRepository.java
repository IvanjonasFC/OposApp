package es.ivanesco.oposapp.api.repositories;

import es.ivanesco.oposapp.api.models.RefreshToken;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Optional;

@Repository
public interface RefreshTokenRepository extends JpaRepository<RefreshToken, Integer> {

    Optional<RefreshToken> findByTokenAndRevokedFalse(String token);

    // Revocar todos los tokens activos de un usuario (al cambiar contraseña o logout)
    @Modifying
    @Transactional
    @Query("UPDATE RefreshToken r SET r.revoked = true WHERE r.usuario.id = :usuarioId AND r.revoked = false")
    void revocarPorUsuario(@Param("usuarioId") Integer usuarioId);

    // Limpieza periódica de tokens expirados y revocados (llamado por @Scheduled)
    @Modifying
    @Transactional
    @Query("DELETE FROM RefreshToken r WHERE r.expiresAt < :ahora OR r.revoked = true")
    void eliminarExpiradosYRevocados(@Param("ahora") LocalDateTime ahora);
}
