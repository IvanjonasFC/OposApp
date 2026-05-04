# ── Etapa 1: build ───────────────────────────────────────────
FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /workspace

# Copiar wrappers primero (mejor cache de capas)
COPY gradlew settings.gradle build.gradle ./
COPY gradle ./gradle
RUN chmod +x gradlew && ./gradlew dependencies --no-daemon -q 2>/dev/null || true

# Copiar fuentes y compilar
COPY src ./src
RUN ./gradlew bootJar --no-daemon -x test -q

# ── Etapa 2: runtime ─────────────────────────────────────────
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Usuario no-root por seguridad
RUN addgroup -S oposapp && adduser -S oposapp -G oposapp
USER oposapp

# Copiar solo el JAR compilado
COPY --from=build /workspace/build/libs/*.jar app.jar

# Puerto expuesto (mismo que server.port en application.yml)
EXPOSE 8081

# Entrypoint: Spring Boot con el perfil NAS activo
ENTRYPOINT ["java", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "-Dspring.profiles.active=${SPRING_PROFILES_ACTIVE:-nas}", \
  "-jar", "app.jar"]
