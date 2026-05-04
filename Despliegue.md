# OposApp — Guia de despliegue en NAS Synology DS920+

## Requisitos previos en el NAS

| Requisito | Estado |
|-----------|--------|
| Docker + Docker Compose instalados (Package Center) | Necesario |
| PostgreSQL 15 corriendo en puerto 5435 | Ya operativo |
| Ollama con modelo qwen2.5-coder:7b-instruct | Ya operativo |
| Puertos 80 y 443 abiertos en el router (NAT) | Necesario para HTTPS |
| Dominio api.tu-dominio.ejemplo.com apuntando a tu IP publica | Necesario |

---

## Paso 1 — Copiar el proyecto al NAS

```bash
# Desde tu PC, via SCP o montando la carpeta compartida
scp -r "tfg futtler ia/" tu_usuario@<IP_NAS>:/volume1/docker/oposapp/
```

O arrastra la carpeta desde el Finder/Explorador al volumen compartido del NAS.

---

## Paso 2 — Configurar las variables de entorno

```bash
cd /volume1/docker/oposapp

# Copiar la plantilla
cp .env.example .env

# Editar con los valores reales (ya estan en el .env del repo local)
nano .env
```

Valores a revisar en `.env`:
- `DB_PASSWORD` — contrasena de PostgreSQL
- `JWT_SECRET` — debe ser base64 de minimo 64 bytes (ya generado)
- `MAIL_PASSWORD` — Gmail App Password de 16 caracteres
- `OLLAMA_URL` — confirmar que es `http://<IP_OLLAMA>:11434`

---

## Paso 3 — Construir y levantar los contenedores

```bash
cd /volume1/docker/oposapp

# Primera vez (con build)
docker-compose up -d --build

# Verificar que todo esta OK
docker-compose ps
docker-compose logs -f oposapp-api
```

El backend tarda ~60 segundos en arrancar (healthcheck).

---

## Paso 4 — Verificar el despliegue

```bash
# Health del backend (via Caddy con HTTPS)
curl https://api.tu-dominio.ejemplo.com/actuator/health

# Swagger UI (sin autenticacion)
# Abrir en el navegador:
# https://api.tu-dominio.ejemplo.com/swagger-ui.html

# Logs en tiempo real
docker-compose logs -f
```

---

## Compilar la APK de produccion (Flutter)

```bash
cd oposapp

# APK con URL de produccion (HTTPS NAS)
flutter build apk --dart-define=PRODUCCION=true --release

# La APK queda en:
# build/app/outputs/flutter-apk/app-release.apk
```

---

## Operaciones habituales

```bash
# Reiniciar solo el backend (sin reconstruir imagen)
docker-compose restart oposapp-api

# Actualizar despues de cambios en el codigo
docker-compose up -d --build oposapp-api

# Parar todo
docker-compose down

# Ver logs del backend
docker-compose logs -f oposapp-api

# Ver logs de Caddy
docker-compose logs -f oposapp-caddy
```

---

## Backup de la base de datos

```bash
# Ejecutar desde el NAS (PostgreSQL ya corre en contenedor independiente)
docker exec -t nombre_contenedor_postgres pg_dump \
  -U n8n -d tfg_db -n tfg \
  > /volume1/backup/oposapp_$(date +%Y%m%d).sql
```

Automatizar con una tarea programada en el DSM de Synology (Control Panel > Task Scheduler).

---

## Troubleshooting

| Problema | Solucion |
|----------|----------|
| `Connection refused` al backend | Esperar 60s al healthcheck; revisar logs |
| Caddy no obtiene certificado | Verificar NAT 80/443 y DNS del dominio |
| Ollama no responde | Comprobar `curl http://<IP_OLLAMA>:11434/api/tags` desde el NAS |
| Error `ddl-auto=validate` | El schema tfg no coincide con las entidades; revisar migraciones SQL |
| JWT 401 en Flutter | Verificar que la APK usa `--dart-define=PRODUCCION=true` |
