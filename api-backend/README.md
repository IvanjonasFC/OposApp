# OposApp — Backend API REST

## TFG · Desarrollo de Aplicaciones Multiplataforma · Curso 2025-2026

### Autor: Iván Jonas Fernández Correa

---

## Índice

1. [Descripción](#1-descripción)
2. [Stack tecnológico](#2-stack-tecnológico)
3. [Arquitectura y estructura del proyecto](#3-arquitectura-y-estructura-del-proyecto)
4. [Capas del sistema](#4-capas-del-sistema)
5. [Endpoints principales](#5-endpoints-principales)
6. [Seguridad](#6-seguridad)
7. [Integración con Ollama IA](#7-integración-con-ollama-ia)
8. [Base de datos](#8-base-de-datos)
9. [Configuración y perfiles](#9-configuración-y-perfiles)
10. [Cómo arrancar en desarrollo](#10-cómo-arrancar-en-desarrollo)
11. [Despliegue en producción NAS](#11-despliegue-en-producción-nas)
12. [Pruebas con Swagger](#12-pruebas-con-swagger)

---

## 1. Descripción

API RESTful del proyecto **OposApp** — aplicación móvil para opositores del sector público asturiano.

El backend centraliza:

- La **autenticación y autorización** de usuarios con JWT.
- La **orquestación de la generación de tests** con IA local (Ollama).
- El acceso a las **convocatorias del BOPA** (previamente procesadas por n8n).
- Las **estadísticas de progreso** de cada usuario.
- El **panel de administración** para gestión de usuarios y auditoría.

---

## 2. Stack tecnológico

| Componente    | Tecnología                     | Versión       |
| ------------- | ------------------------------ | ------------- |
| Framework     | Spring Boot                    | 3.5.11        |
| Lenguaje      | Java                           | 21            |
| Build         | Gradle                         | 8.x           |
| Seguridad     | Spring Security + JWT (jjwt)   | HS512, 7 días |
| Contraseñas   | BCrypt                         | Factor 10     |
| Rate Limiting | Bucket4j                       | 8.10.1        |
| ORM           | Spring Data JPA / Hibernate 6  | -             |
| Base de datos | PostgreSQL                     | 15            |
| Documentación | springdoc-openapi (Swagger UI) | 2.7.0         |
| Email         | Spring Mail + Thymeleaf        | Gmail SMTP    |
| Boilerplate   | Lombok                         | -             |
| Contenedor    | Docker + Caddy                 | -             |

---

## 3. Arquitectura y estructura del proyecto

```
api-backend/
├── src/
│   ├── main/
│   │   ├── java/es/ivanesco/oposapp/api/
│   │   │   ├── config/          ← Seguridad, JWT, Rate Limiting, CORS
│   │   │   ├── controllers/     ← Endpoints REST (@RestController)
│   │   │   ├── dtos/            ← Objetos de transferencia de datos
│   │   │   ├── exceptions/      ← Manejo global de errores
│   │   │   ├── models/          ← Entidades JPA (tablas de la BD)
│   │   │   ├── repositories/    ← Acceso a datos (Spring Data JPA)
│   │   │   ├── services/        ← Lógica de negocio
│   │   │   └── OposAppBackendApplication.java
│   │   └── resources/
│   │       ├── migrations/      ← Scripts SQL de migración
│   │       ├── templates/       ← Plantillas email (Thymeleaf)
│   │       ├── application.yml          ← Config local (dev)
│   │       ├── application-nas.yml      ← Config producción NAS
│   │       └── application.yml.example ← Plantilla documentada
├── Dockerfile                   ← Build multistage JRE Alpine
├── build.gradle                 ← Dependencias y plugins
├── gradlew / gradlew.bat        ← Wrapper Gradle (no instalar Gradle)
└── LEVANTAR BACKEND.txt         ← Guía de arranque rápido
```

---

## 4. Capas del sistema

El backend sigue la **arquitectura en capas** estándar de Spring:

```
HTTP Request
     │
     ▼
┌─────────────────────────────────────────────────────┐
│  RateLimitFilter → JwtAuthenticationFilter          │  ← Filtros pre-autenticación
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│  Controllers (@RestController)                       │  ← Capa de presentación
│  Reciben DTO de request, validan con @Valid          │
│  Devuelven siempre ResponseEntity<T>                 │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│  Services (@Service)                                 │  ← Lógica de negocio
│  @Transactional para garantizar atomicidad           │
│  Orquestan repositorios y servicios externos         │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│  Repositories (JpaRepository<Entidad, TipoId>)       │  ← Acceso a datos
│  Queries JPQL o métodos por convención de nombre     │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│  Models (@Entity)                                    │  ← Mapeo objeto-relacional
│  @Table(schema="tfg") en todas las entidades         │
└─────────────────────────────────────────────────────┘
```

### Ficheros por capa

**`config/`** — Configuración transversal
| Fichero | Función |
|---------|---------|
| `SecurityConfig.java` | Cadena de filtros Spring Security, CORS, rutas públicas/admin |
| `JwtAuthenticationFilter.java` | Extrae y valida el JWT en cada petición |
| `RateLimitFilter.java` | Bucket4j — 100 req/min por IP |
| `AppConfig.java` | Bean `RestTemplate` para llamadas a Ollama |
| `WebMvcConfig.java` | Configuración adicional MVC |

**`controllers/`** — Endpoints REST
| Controlador | Prefijo | Función |
|-------------|---------|---------|
| `AuthController` | `/api/auth` | Login, registro, verificación email, refresh token |
| `TestController` | `/api/tests` | Generar, consultar estado, obtener test, enviar respuestas |
| `BopaController` | `/api/convocatorias` | Listado, búsqueda full-text, favoritos |
| `EstadisticasController` | `/api/estadisticas` | KPIs y dashboard de progreso |
| `UserController` | `/api/user` | Perfil, exportar datos (RGPD), eliminar cuenta |
| `AdminController` | `/api/admin` | Panel admin: usuarios, auditoría, estadísticas, Ollama |
| `NotificacionesController` | `/api/notificaciones` | Gestión de notificaciones del sistema |
| `AdsController` | `/api/ads` | Servicio de anuncios internos (monetización) |

**`models/`** — Entidades JPA (todas en schema `tfg`)
| Entidad | Tabla | Descripción |
|---------|-------|-------------|
| `Usuario` | `usuarios` | Implementa `UserDetails` — autenticación por email |
| `SolicitudGeneracion` | `solicitudes_generacion` | Petición de test a Ollama |
| `TestEntity` | `tests` | Test generado con preguntas asociadas |
| `Pregunta` | `preguntas` | Pregunta tipo test con 4 opciones |
| `SesionTest` | `sesiones_test` | Intento del usuario con su puntuación |
| `RespuestaUsuario` | `respuestas_usuario` | Respuesta individual a cada pregunta |
| `EstadisticasUsuario` | `estadisticas_usuario` | KPIs agregados del usuario |
| `Convocatoria` | `convocatorias` | Convocatoria del BOPA (scraping vía n8n) |
| `Notificacion` | `notificaciones` | Mensajes del sistema al usuario |
| `RefreshToken` | `refresh_tokens` | Trazabilidad de tokens JWT emitidos |
| `SolicitudBaja` | `solicitudes_baja` | RGPD Art. 17 — cola de borrado en 48h |
| `Anuncio` | `anuncios` | Anuncios internos del sistema de monetización |

**`services/`** — Lógica de negocio
| Servicio | Función |
|----------|---------|
| `AuthService` | Registro, login, verificación email, refresh token |
| `JwtService` | Generación y validación de tokens HS512 |
| `TestService` | Construcción del prompt, parsing de Ollama, evaluación |
| `TestAsyncExecutor` | Ejecuta `procesarTest` en hilo separado (`@Async`) |
| `OllamaService` | Llamadas HTTP a Ollama, detección de familia de modelo |
| `BopaService` | Queries paginadas y full-text sobre convocatorias |
| `EstadisticasService` | Cálculo de KPIs y evolución temporal |
| `UserService` | Edición de perfil, exportación RGPD, soft delete |
| `AuditService` | Registro inmutable de acciones en `audit_log` |
| `NotificacionService` | Creación y consulta de notificaciones |
| `EmailService` | Envío de emails transaccionales con Thymeleaf |
| `AdminService` | Operaciones exclusivas del panel de administración |
| `UserDetailsServiceImpl` | Carga usuario por email para Spring Security |

---

## 5. Endpoints principales

La documentación completa e interactiva está en Swagger:

```
http://localhost:8081/swagger-ui.html
```

Resumen rápido de los grupos de endpoints:

```
POST  /api/auth/registro              → Crear cuenta (+ envío email verificación)
POST  /api/auth/login                 → Login → devuelve JWT
POST  /api/auth/refresh               → Renovar JWT sin contraseña
GET   /api/auth/verificar-email?token → Verificar email desde enlace

GET   /api/convocatorias              → Listado paginado (?page=0&size=20)
GET   /api/convocatorias/buscar?q=    → Búsqueda full-text (PostgreSQL tsquery)
POST  /api/convocatorias/{id}/guardar → Guardar en favoritos
GET   /api/convocatorias/guardadas    → Mis favoritos

POST  /api/tests/generate             → Crear solicitud de generación con IA
GET   /api/tests/mis-solicitudes      → Historial del usuario
GET   /api/tests/solicitud/{id}/estado→ Polling: pendiente / procesando / completado
GET   /api/tests/{id}                 → Test completo con preguntas
PUT   /api/tests/{id}/respuestas      → Enviar respuestas y obtener corrección

GET   /api/estadisticas/mias          → KPIs + historial + temas débiles

GET   /api/user/me                    → Perfil propio
PUT   /api/user/perfil                → Editar nombre y apellidos
GET   /api/user/export                → Exportar datos JSON (RGPD Art. 20)
POST  /api/user/delete                → Solicitar baja (RGPD Art. 17)

GET   /api/notificaciones             → Mis notificaciones
PATCH /api/notificaciones/{id}/leer   → Marcar como leída

GET   /api/ads/activo                 → Anuncio activo (para usuario FREE)

GET   /api/admin/stats                → Dashboard global (solo ADMIN)
GET   /api/admin/usuarios             → Listado de usuarios (solo ADMIN)
PUT   /api/admin/usuarios/{id}/rol    → Cambiar rol (solo ADMIN)
GET   /api/admin/audit                → Log de auditoría (solo ADMIN)
GET   /api/admin/ollama/status        → Estado del servidor IA (solo ADMIN)
```

---

## 6. Seguridad

### Autenticación JWT

- El login devuelve un token **HS512** firmado con clave de 512 bits.
- El token lleva los claims `sub` (email), `rol` y `usuarioId`.
- Validez: **7 días**. El cliente Flutter lo renueva automáticamente cuando quedan menos de 24h.
- El filtro `JwtAuthenticationFilter` procesa cada petición antes de llegar al controlador.

### Rutas protegidas

```
Públicas:   /api/auth/**  ·  /swagger-ui/**  ·  /v3/api-docs/**
Admin:      /api/admin/** → requiere ROLE_ADMIN en el JWT
El resto:   cualquier usuario autenticado
```

### Rate Limiting

- Bucket4j aplica **100 peticiones por minuto por IP**.
- Responde `HTTP 429 Too Many Requests` si se supera el límite.
- Se aplica antes del filtro JWT para proteger también los endpoints de login.

### Bloqueo por intentos fallidos

- Tras **4 intentos fallidos** de login, la cuenta se bloquea **15 minutos**.
- El desbloqueo es automático; el usuario recibe una notificación en la app.

### RGPD

| Artículo                    | Implementación                                                 |
| --------------------------- | -------------------------------------------------------------- |
| Art. 6 — Consentimiento     | Campo `rgpd_aceptado` + timestamp en BD                        |
| Art. 17 — Derecho al olvido | Soft delete inmediato + borrado físico en 48h vía `@Scheduled` |
| Art. 20 — Portabilidad      | Endpoint `/api/user/export` devuelve JSON completo             |

---

## 7. Integración con Ollama IA

El backend se comunica con Ollama mediante `RestTemplate` (HTTP síncrono, ejecutado en hilo `@Async`).

### Flujo de generación asíncrona

```
1. Flutter → POST /api/tests/generate
2. Backend crea SolicitudGeneracion (estado: "pendiente")
3. TestAsyncExecutor.procesarTest() en hilo separado:
   a. Estado → "procesando"
   b. Construye prompt en español con tema, oposición y dificultad
   c. Llama a OllamaService.sendPrompt(modelo, prompt)
   d. Parsea la respuesta JSON (soporta formato array y objeto wrapper)
   e. Guarda TestEntity + List<Pregunta> en BD
   f. Estado → "completado"
   g. Crea Notificacion al usuario
4. Flutter hace polling GET /api/tests/solicitud/{id}/estado cada 3s
5. Al detectar "completado" → carga el test y navega al examen
```

### Gestión de modelos

El servicio detecta automáticamente la familia del modelo:

- `qwen3*` → **PREMIUM**: `think=false` a nivel raíz, sin `format=json`
- Cualquier otro → **FREE**: `format="json"`, temperatura 0.3

Esto es necesario porque `format="json"` hace que los modelos Qwen3 generen solo 1 pregunta en lugar del array completo.

---

## 8. Base de datos

- **Motor**: PostgreSQL 15, schema `tfg`
- **Conexión**: `<IP_NAS>:5435` (NAS Synology DS920+, contenedor Docker)
- **ddl-auto**: `none` en desarrollo, `validate` en producción NAS
- **Pool de conexiones**: HikariCP, máximo 10 conexiones

### Reglas de las entidades JPA

```java
// Todas las entidades llevan:
@Table(name = "nombre_tabla", schema = "tfg")

// Los IDs usan autoincremento de PostgreSQL:
@GeneratedValue(strategy = GenerationType.IDENTITY)

// Boilerplate con Lombok:
@Data @Builder @NoArgsConstructor @AllArgsConstructor

// NUNCA usar scale/precision en @Column para Double/Float
// (causa IllegalArgumentException en Hibernate 6)
// Usar BigDecimal si se necesita precisión decimal
```

### Scripts de migración

Los scripts SQL están en `src/main/resources/migrations/`.
Se aplican manualmente — el backend NUNCA modifica el schema automáticamente en producción.

---

## 9. Configuración y perfiles

| Fichero                   | Perfil  | Uso                                                  |
| ------------------------- | ------- | ---------------------------------------------------- |
| `application.yml`         | default | Desarrollo local — valores con `${ENV:fallback_dev}` |
| `application-nas.yml`     | nas     | Producción NAS — solo `${ENV}`, sin fallback         |
| `application.yml.example` | —       | Plantilla documentada para referencia                |
| `application-local.yml`   | local   | Overrides opcionales para desarrollo                 |

Activar perfil NAS:

```bash
# Al arrancar directamente
./gradlew bootRun --args="--spring.profiles.active=nas"

# Con Docker (carga .env automáticamente)
docker-compose up -d --build
```

---

## 10. Cómo arrancar en desarrollo

Ver `LEVANTAR BACKEND.txt` para instrucciones detalladas paso a paso.

Resumen rápido:

```bash
# Arrancar (Windows)
.\gradlew.bat bootRun

# Arrancar (Linux/macOS)
./gradlew bootRun

# Verificar que está corriendo
curl http://localhost:8081/actuator/health

# Abrir Swagger
start http://localhost:8081/swagger-ui.html
```

---

## 11. Despliegue en producción NAS

```bash
# 1. Copiar el proyecto al NAS
scp -r "api-backend/" tu_usuario@<IP_NAS>:/volume1/docker/oposapp/

# 2. Configurar variables de entorno
cp ../.env.example ../.env
nano ../.env    # Rellenar valores reales

# 3. Construir y arrancar
cd /volume1/docker/oposapp
docker-compose up -d --build

# 4. Ver logs
docker-compose logs -f oposapp-api

# 5. Verificar health check
curl https://api.tu-dominio.ejemplo.com/actuator/health
```

---

## 12. Pruebas con Swagger

Las pruebas funcionales del TFG se realizaron con Swagger UI.
Swagger está disponible sin autenticación en:

```
http://localhost:8081/swagger-ui.html
```

### Flujo de prueba completo

1. Crear cuenta: `POST /api/auth/registro`
2. Hacer login: `POST /api/auth/login` → copiar el token de la respuesta
3. Pulsar **Authorize** (arriba a la derecha en Swagger) → pegar `Bearer <token>`
4. A partir de ahí, todos los endpoints autenticados funcionan directamente desde el navegador.

### Crear el primer usuario ADMIN

Ejecutar el script `bootstrap_admin.sql` en Adminer o pgAdmin:

```sql
-- Actualizar rol del usuario (sustituir el id correspondiente)
UPDATE tfg.usuarios SET rol = 'ADMIN' WHERE email = 'tu_email@ejemplo.com';
```

---

_Desarrollado como Trabajo de Fin de Grado — DAM · Asturias · 2026_
