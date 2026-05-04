package es.ivanesco.oposapp.api.services;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.thymeleaf.TemplateEngine;
import org.thymeleaf.context.Context;

import jakarta.mail.MessagingException;
import jakarta.mail.internet.MimeMessage;

@Slf4j
@Service
@RequiredArgsConstructor
public class EmailService {

    private final JavaMailSender mailSender;
    private final TemplateEngine templateEngine;

    @Value("${spring.mail.username}")
    private String fromEmail;

    @Value("${app.url:http://localhost:8081}")
    private String appUrl;

    /**
     * Envía el correo de verificación de forma ASÍNCRONA (@Async).
     * El hilo HTTP del registro no espera al SMTP → respuesta inmediata al usuario.
     * Spring gestiona un ThreadPoolExecutor separado para estas tareas.
     */
    @Async
    public void enviarEmailVerificacion(String destinatario, String username, String token) {
        try {
            Context context = new Context();
            context.setVariable("username", username);
            context.setVariable("urlVerificacion",
                    appUrl + "/api/auth/verificar-email?token=" + token);

            String htmlContent = templateEngine.process("email-verificacion", context);

            MimeMessage mensaje = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(mensaje, true, "UTF-8");
            helper.setFrom(fromEmail, "OposApp");
            helper.setTo(destinatario);
            helper.setSubject("✅ Confirma tu cuenta en OposApp");
            helper.setText(htmlContent, true);

            mailSender.send(mensaje);
            log.info("[EMAIL] Verificación enviada a: {}", destinatario);

        } catch (MessagingException | java.io.UnsupportedEncodingException e) {
            log.error("[EMAIL] Error enviando verificación a {}: {}", destinatario, e.getMessage());
        }
    }
}
