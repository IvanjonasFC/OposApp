package es.ivanesco.oposapp.api.config;

import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Bucket;
import io.github.bucket4j.Refill;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Duration;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class RateLimitFilter extends OncePerRequestFilter {

    private final Map<String, Bucket> cacheIp = new ConcurrentHashMap<>();
    private final Map<String, Bucket> cacheUser = new ConcurrentHashMap<>();

    private Bucket newIpBucket() {
        return Bucket.builder()
                .addLimit(Bandwidth.classic(1000, Refill.intervally(1000, Duration.ofMinutes(1))))
                .build();
    }

    private Bucket newUserBucket() {
        return Bucket.builder()
                .addLimit(Bandwidth.classic(100, Refill.intervally(100, Duration.ofMinutes(1))))
                .build();
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {

        String ip = request.getRemoteAddr();
        Bucket ipBucket = cacheIp.computeIfAbsent(ip, k -> newIpBucket());

        if (!ipBucket.tryConsume(1)) {
            response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
            response.setContentType("application/json");
            response.getWriter()
                    .write("{\"error\": \"RATE_LIMIT\", \"message\": \"Too many requests from IP\", \"status\": 429}");
            return;
        }

        String authHeader = request.getHeader("Authorization");
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7);
            Bucket userBucket = cacheUser.computeIfAbsent(token, k -> newUserBucket());

            if (!userBucket.tryConsume(1)) {
                response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
                response.setContentType("application/json");
                response.getWriter().write(
                        "{\"error\": \"RATE_LIMIT\", \"message\": \"Too many requests for user\", \"status\": 429}");
                return;
            }
        }

        filterChain.doFilter(request, response);
    }
}
