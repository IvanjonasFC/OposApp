# OposApp — Base de Datos PostgreSQL
## Schema: `tfg` | Motor: PostgreSQL 15

---

## Ficheros incluidos

| Fichero | Descripción |
|---------|-------------|
| `01_schema.sql` | Crea todas las tablas, índices y relaciones del schema `tfg` |
| `02_datos_muestra.sql` | Inserta datos de demostración para probar la aplicación |

---

## Requisitos

- PostgreSQL 14 o superior instalado
- Cliente `psql` disponible en el PATH
- O Docker instalado (alternativa sin instalar PostgreSQL)

---

## Opción A — Restaurar con PostgreSQL local

```bash
# 1. Crear la base de datos
createdb -U postgres oposapp_demo

# 2. Crear el schema y todas las tablas
psql -U postgres -d oposapp_demo -f 01_schema.sql

# 3. Cargar datos de demostración
psql -U postgres -d oposapp_demo -f 02_datos_muestra.sql
```

Verificar que todo se cargó:
```bash
psql -U postgres -d oposapp_demo -c "SELECT tablename FROM pg_tables WHERE schemaname = 'tfg' ORDER BY tablename;"
```

---

## Opción B — Restaurar con Docker (sin instalar PostgreSQL)

```bash
# 1. Levantar un contenedor PostgreSQL 15
docker run --name oposapp-db \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=oposapp_demo \
  -p 5432:5432 \
  -d postgres:15

# 2. Esperar a que arranque
sleep 5

# 3. Cargar el schema
docker exec -i oposapp-db psql -U postgres -d oposapp_demo < 01_schema.sql

# 4. Cargar datos de muestra
docker exec -i oposapp-db psql -U postgres -d oposapp_demo < 02_datos_muestra.sql

# 5. Verificar
docker exec oposapp-db psql -U postgres -d oposapp_demo \
  -c "SELECT COUNT(*) FROM tfg.usuarios;"
```

Para parar el contenedor:
```bash
docker stop oposapp-db && docker rm oposapp-db
```

---

## Conectar el backend Spring Boot a esta BD

Edita `api-backend/src/main/resources/application.yml`:

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/oposapp_demo?currentSchema=tfg
    username: postgres
    password: postgres
  jpa:
    hibernate:
      ddl-auto: validate
```

---

## Usuarios de demostración

| Email | Contraseña | Rol | Acceso |
|-------|-----------|-----|--------|
| `admin@oposapp.example` | `Test1234!` | ADMIN | Panel de administración completo |
| `usuario@oposapp.example` | `Test1234!` | USER | Acceso estándar a la app |

---

## Estructura del schema `tfg`

```
usuarios              → Cuentas de usuario con roles y autenticación
tests                 → Tests generados por la IA
solicitudes_generacion→ Cola de peticiones a Ollama (pendiente/procesando/completado)
preguntas             → Preguntas tipo test con 4 opciones y explicación IA
sesiones_test         → Intentos realizados por cada usuario
respuestas_usuario    → Respuesta individual a cada pregunta
estadisticas_usuario  → KPIs agregados de progreso (tests, aciertos, rachas)
convocatorias         → Convocatorias del BOPA scrapeadas automáticamente
convocatorias_guardadas → Favoritos de cada usuario
notificaciones        → Mensajes del sistema al usuario
refresh_tokens        → Tokens JWT emitidos (para trazabilidad y revocación)
audit_log             → Registro inmutable de acciones (seguridad y auditoría)
anuncios              → Anuncios internos del sistema de monetización
solicitudes_baja      → Cola de borrado RGPD Art. 17 (soft delete 48h)
reportes              → Informes IA por test completado
historial_scraping    → Registro de ejecuciones del scraping del BOPA
```
