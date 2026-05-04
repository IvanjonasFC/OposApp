# OposApp — Frontend Flutter
## TFG · Desarrollo de Aplicaciones Multiplataforma · Curso 2025-2026
### Autor: Iván Jonas Fernández Correa

---

## Índice
1. [Descripción del proyecto](#1-descripción-del-proyecto)
2. [Arquitectura de la app](#2-arquitectura-de-la-app)
3. [Estructura de carpetas](#3-estructura-de-carpetas)
4. [Pantallas y funcionalidades](#4-pantallas-y-funcionalidades)
5. [Capa de datos — Modelos](#5-capa-de-datos--modelos)
6. [Servicios](#6-servicios)
7. [Dependencias](#7-dependencias)
8. [Cómo ejecutar en desarrollo](#8-cómo-ejecutar-en-desarrollo)
9. [Cómo compilar la APK de producción](#9-cómo-compilar-la-apk-de-producción)
10. [Conexión con el backend](#10-conexión-con-el-backend)
11. [Flujo de generación de tests con IA](#11-flujo-de-generación-de-tests-con-ia)
12. [Caché offline](#12-caché-offline)
13. [Seguridad y RGPD](#13-seguridad-y-rgpd)
14. [Requisitos cumplidos](#14-requisitos-cumplidos)

---

## 1. Descripción del proyecto

OposApp es una aplicación móvil para **opositores del sector público en Asturias** que automatiza:

- El seguimiento de convocatorias publicadas en el **BOPA** (Boletín Oficial del Principado de Asturias).
- La generación de **tests personalizados mediante IA local** (Ollama + Qwen3), sin enviar datos a servicios externos.
- El seguimiento del **progreso y estadísticas** de estudio del usuario.

El frontend está desarrollado en **Flutter 3.24** y es compatible con **Android** y navegador web.
Se comunica con un backend **Spring Boot 3** a través de una API REST con autenticación JWT.

---

## 2. Arquitectura de la app

La app sigue una arquitectura **orientada a servicios** con separación de responsabilidades:

```
┌─────────────────────────────────────────────┐
│                   UI Layer                  │
│   Screens (StatefulWidget / StatelessWidget)│
│   Widgets reutilizables                     │
└──────────────────┬──────────────────────────┘
                   │  llama a
┌──────────────────▼──────────────────────────┐
│               Service Layer                 │
│   ApiService     AuthService                │
│   AdminService   NetworkService             │
└──────────────────┬──────────────────────────┘
                   │  HTTP (Dio)
┌──────────────────▼──────────────────────────┐
│           Backend Spring Boot               │
│   API REST  →  PostgreSQL 15                │
│   Ollama IA →  Qwen3 64k / Qwen2.5-Coder   │
└─────────────────────────────────────────────┘
```

**Patrones de diseño aplicados:**
- **Singleton** para los servicios (`ApiService`, `AuthService`) — métodos estáticos con instancia única de `Dio`.
- **Observer** para el polling de tests — `Timer.periodic` que pregunta al backend cada 3 segundos.
- **Repository** para la capa de caché (`HiveCache`) — desacopla el origen del dato (red u offline).
- **GlobalKey** para comunicación entre `HomeScreen` y `TestsScreen` sin `setState` en el padre.

---

## 3. Estructura de carpetas

```
lib/
├── main.dart                      # Punto de entrada, inicialización de Hive
│
├── core/
│   ├── constants/
│   │   └── api_constants.dart     # URLs base, endpoints, timeouts
│   ├── errors/
│   │   └── app_exception.dart     # Tipos de error de dominio
│   ├── routing/
│   │   └── app_router.dart        # Todas las rutas de la app (go_router)
│   └── theme/
│       ├── app_colors.dart        # Paleta de colores centralizada
│       └── app_theme.dart         # ThemeData global (Material Design 3)
│
├── models/                        # Clases de datos (DTOs que llegan del backend)
│   ├── usuario.dart
│   ├── convocatoria.dart
│   ├── solicitud_generacion.dart
│   ├── pregunta.dart
│   ├── estadisticas.dart
│   ├── notificacion.dart
│   ├── audit_log.dart
│   └── dashboard_stats.dart
│
├── services/                      # Comunicación con el backend y lógica
│   ├── api_service.dart           # Cliente HTTP principal (Dio)
│   ├── auth_service.dart          # Sesión local: token JWT, SharedPreferences
│   ├── admin_service.dart         # Endpoints del panel de administración
│   └── network_service.dart       # Detección de red (online/offline)
│
├── cache/
│   └── hive_cache.dart            # Caché local offline (Hive)
│
├── screens/                       # Una carpeta → una pantalla
│   ├── splash_screen.dart         # Pantalla de carga + comprobación de sesión
│   ├── login_screen.dart          # Login + Registro (en una misma pantalla)
│   ├── home_screen.dart           # Shell principal con barra de navegación
│   ├── bopa_screen.dart           # Listado de convocatorias + favoritos
│   ├── tests_screen.dart          # Historial de tests + polling de estado
│   ├── generate_screen.dart       # Formulario para lanzar generación de test
│   ├── test_screen.dart           # Examen: preguntas + navegación + envío
│   ├── resultado_test_screen.dart # Resultados + corrección con IA
│   ├── progreso_screen.dart       # Dashboard de estadísticas (KPIs + gráfico)
│   ├── perfil_screen.dart         # Perfil de usuario + RGPD
│   └── admin_dashboard_screen.dart # Panel exclusivo para ROLE_ADMIN
│
└── widgets/                       # Componentes reutilizables
    ├── app_toast.dart             # Snackbar personalizado (éxito/error/warning)
    ├── ad_banner_widget.dart      # Banner publicitario (monetización)
    └── reporte_dialog.dart        # Diálogo con el informe IA del test
```

---

## 4. Pantallas y funcionalidades

### `SplashScreen`
- Muestra el logo con animación de escala y fade.
- Comprueba si hay sesión activa (`AuthService.isLoggedIn()`).
- Redirige a `/home` si ya está autenticado, o a `/login` si no.

### `LoginScreen`
- **Modo Login**: email + contraseña → POST `/api/auth/login`.
- **Modo Registro**: nombre + email + contraseña + checkbox RGPD → POST `/api/auth/registro`.
- Un solo `StatefulWidget` con un booleano `_isRegistro` que alterna entre modos.
- Animación de transición entre modos (fade + slide).
- Gestión de errores: muestra un `SnackBar` con el mensaje del backend.
- Acepta el parámetro `modoRegistroInicial: true` para abrir en modo registro desde la ruta `/register`.

### `HomeScreen`
- **Shell principal** que contiene las 3 pestañas con `IndexedStack` (sin recrear widgets).
- Barra de navegación inferior: BOPA · Tests · Progreso.
- AppBar dinámica con:
  - Badge de notificaciones no leídas (se actualiza con polling ligero).
  - Icono de administración (solo visible si `ROLE_ADMIN`).
  - Icono de perfil.
- FAB contextual en la pestaña Tests para lanzar un test nuevo.

### `BOPAScreen`
- Lista paginada de convocatorias del BOPA (carga 20 en 20 con scroll infinito).
- Búsqueda full-text con debounce de 500ms contra el backend.
- Dos pestañas: **Todas** y **Favoritas**.
- Guardar/quitar favoritos con animación y feedback haptico.
- Modo offline: muestra las últimas 30 convocatorias desde caché Hive si no hay red.

### `TestsScreen`
- Historial de solicitudes de generación del usuario.
- **Polling automático** cada 3 segundos para solicitudes en estado `pendiente` o `procesando`.
  - Cuando el test pasa a `completado` → notificación y el card se actualiza.
  - Los timers se cancelan automáticamente en `dispose()` para evitar memory leaks.
- Muestra: tema, oposición, dificultad, número de preguntas, veces realizado y última nota.

### `GenerateScreen`
- Formulario para configurar la generación de un test:
  - Selector de oposición (5 categorías).
  - Campo de tema libre.
  - Slider de preguntas (5 a 20).
  - Selector de dificultad (Baja / Media / Alta).
- Badge PREMIUM visible si el usuario tiene ese plan.
- Al enviar, crea la solicitud en el backend y vuelve a la pestaña Tests (el polling se encarga del resto).

### `TestScreen`
- Presenta las preguntas en formato `PageView` (deslizables).
- Barra de progreso animada (`AnimationController`).
- Guarda la respuesta seleccionada en `Map<int, String>` (preguntaId → letra).
- Mide el tiempo de respuesta por pregunta.
- Al finalizar, envía las respuestas con PUT `/api/tests/{id}/respuestas` y navega a resultados.

### `ResultadoTestScreen`
- Muestra: nota final, aciertos, fallos, porcentaje.
- Lista expandible de todas las preguntas con:
  - Respuesta del usuario (verde si correcta, rojo si no).
  - Respuesta correcta destacada.
  - Explicación generada por la IA.
- Botón para volver a hacer el mismo test.

### `ProgresoScreen`
- **KPIs**: tests completados, preguntas respondidas, % de aciertos, días consecutivos.
- **Gráfico de línea** (`fl_chart`) con los últimos 7 tests.
- **Lista de temas débiles** (menor porcentaje de acierto).
- **Historial** de los últimos 50 tests con nota codificada por color.
- Se recarga automáticamente cuando la app vuelve al primer plano (`WidgetsBindingObserver`).

### `PerfilScreen`
- Header con iniciales del usuario, badge de verificación y plan.
- **Editar perfil**: nombre y apellidos (actualiza backend + SharedPreferences local).
- **Exportar datos** (RGPD Art. 20): descarga JSON con todo el historial.
- **Política de privacidad**: información clara sin emojis.
- **Acerca de OposApp**: stack tecnológico.
- **Cerrar sesión** y **Eliminar cuenta** (RGPD Art. 17 — soft delete con confirmación).

### `AdminDashboardScreen`
- Solo accesible para usuarios con `ROLE_ADMIN`.
- Pestañas: **Resumen** · **Usuarios** · **Auditoría** · **Preguntas**.
- Dashboard con métricas globales: total usuarios, tests hoy, solicitudes pendientes.
- Gestión de usuarios: cambiar rol, activar/desactivar cuenta.
- Log de auditoría: registro de todas las acciones con timestamp.
- Estado de Ollama (online/offline).

---

## 5. Capa de datos — Modelos

Cada modelo es un **data class inmutable** con:
- Constructor `const`/`required` para todos los campos obligatorios.
- Factory `fromJson(Map<String, dynamic>)` para deserializar las respuestas del backend.
- Método `toJson()` para serializar al enviar datos.

| Modelo | Tabla BD | Descripción |
|--------|----------|-------------|
| `Usuario` | `tfg.usuarios` | Datos del usuario autenticado |
| `Convocatoria` | `tfg.convocatorias` | Convocatoria del BOPA |
| `SolicitudGeneracion` | `tfg.solicitudes_generacion` | Petición de test a la IA |
| `Pregunta` | `tfg.preguntas` | Pregunta tipo test generada |
| `Estadisticas` | `tfg.estadisticas_usuario` | KPIs del progreso del usuario |
| `Notificacion` | `tfg.notificaciones` | Notificaciones del sistema |
| `AuditLog` | `tfg.audit_log` | Registro de acciones (admin) |
| `DashboardStats` | (calculado) | Métricas del panel admin |

---

## 6. Servicios

### `ApiService`
Cliente HTTP centralizado basado en **Dio**. Configurado con:
- URL base desde `ApiConstants.baseUrl` (cambia automáticamente según plataforma/entorno).
- **Interceptor JWT**: añade `Authorization: Bearer <token>` a todas las peticiones.
  - Si el token está expirado → logout automático + redirección a `/login`.
  - Si el token expira en menos de 24h → lo renueva silenciosamente vía `/api/auth/refresh`.
- Timeouts diferenciados: 8s para peticiones normales, 120s para llamadas a Ollama.
- Método `_handleError()` que mapea códigos HTTP a `AppException` tipados.

### `AuthService`
Gestiona la **sesión local** del usuario:
- Token JWT guardado en **`FlutterSecureStorage`** (cifrado en el keystore del dispositivo).
- Datos del usuario (id, nombre, email, rol) en **`SharedPreferences`**.
- Decodifica el payload del JWT para comprobar expiración sin llamar al servidor.
- Métodos: `saveSession()`, `getToken()`, `logout()`, `isAdmin()`, `isPremium()`, `getCurrentUser()`.

### `AdminService`
Endpoints exclusivos del panel de administración:
- `getDashboardStats()` → `/api/admin/stats`
- `getUsuarios()` → `/api/admin/usuarios`
- `getAuditLog()` → `/api/admin/audit`
- `getPreguntas()` → `/api/admin/preguntas`
- `cambiarRol()` / `cambiarEstado()` → PUT `/api/admin/usuarios/{id}/rol` y `/estado`

### `NetworkService`
Detecta si el dispositivo tiene conexión activa usando `connectivity_plus`.
Usado por `BOPAScreen` y `GenerateScreen` para mostrar mensajes offline.

---

## 7. Dependencias

### HTTP y red
| Paquete | Versión | Uso |
|---------|---------|-----|
| `dio` | ^5.4.0 | Cliente HTTP con interceptores |
| `connectivity_plus` | ^6.0.3 | Detección de red online/offline |
| `network_info_plus` | ^5.0.1 | Información de red local |

### Navegación
| Paquete | Versión | Uso |
|---------|---------|-----|
| `go_router` | ^14.0.0 | Navegación declarativa con deep links |

### Almacenamiento
| Paquete | Versión | Uso |
|---------|---------|-----|
| `shared_preferences` | ^2.2.2 | Datos no sensibles (nombre, email) |
| `flutter_secure_storage` | ^9.2.2 | Token JWT cifrado |
| `hive_flutter` | ^1.1.0 | Caché offline de convocatorias y tests |

### UI y gráficos
| Paquete | Versión | Uso |
|---------|---------|-----|
| `fl_chart` | ^0.66.0 | Gráfico de evolución del progreso |
| `percent_indicator` | ^4.2.3 | KPI circular de aciertos |
| `shimmer` | ^3.0.0 | Skeleton loading mientras carga |
| `flutter_spinkit` | ^5.2.0 | Animaciones de carga |
| `flutter_staggered_animations` | ^1.1.1 | Animaciones de lista escalonadas |
| `confetti` | ^0.7.0 | Animación de celebración en resultados |

### Utilidades
| Paquete | Versión | Uso |
|---------|---------|-----|
| `intl` | ^0.18.1 | Formateo de fechas en español |
| `url_launcher` | ^6.2.2 | Abrir URLs de convocatorias |
| `font_awesome_flutter` | ^10.6.0 | Iconos adicionales |

---

## 8. Cómo ejecutar en desarrollo

### Requisitos previos
- Flutter SDK 3.24 o superior instalado
- Dart SDK incluido con Flutter
- Android Studio o VS Code con el plugin de Flutter
- El backend Spring Boot corriendo (ver README del backend)

### Pasos

```bash
# 1. Clonar el repositorio y entrar al directorio del frontend
cd "tfg futtler ia/oposapp"

# 2. Instalar dependencias
flutter pub get

# 3. Ejecutar en un dispositivo Android físico conectado por USB
flutter run

# 4. Ejecutar en el navegador (útil para desarrollo sin emulador)
flutter run -d chrome

# 5. Ejecutar en emulador Android
# Primero lanzar el emulador desde Android Studio, luego:
flutter run -d emulator-5554
```

### URL del backend en desarrollo

Edita `lib/core/constants/api_constants.dart` según tu entorno:

```dart
// Para dispositivo físico en la misma red que el NAS/PC con el backend:
static const String baseUrlLan = 'http://<IP_NAS>:8081/api';

// Para emulador Android:
static const String baseUrlAndroid = 'http://10.0.2.2:8081/api';

// Para Flutter Web en el mismo PC:
static const String baseUrlLocal = 'http://localhost:8081/api';
```

La selección es automática según la plataforma. El flag `--dart-define=PRODUCCION=true` activa la URL HTTPS del NAS.

---

## 9. Cómo compilar la APK de producción

```bash
# APK de producción apuntando a api.tu-dominio.ejemplo.com (HTTPS)
flutter build apk --dart-define=PRODUCCION=true --release

# La APK resultante estará en:
# build/app/outputs/flutter-apk/app-release.apk
```

Para distribuir por USB sin pasar por Google Play:
```bash
# Instalar directamente en el dispositivo conectado
flutter install --release
```

---

## 10. Conexión con el backend

La URL base se resuelve en `ApiConstants.baseUrl` de forma automática:

```dart
static String get baseUrl {
  if (_esProduccion) return baseUrlProduccion; // https://api.tu-dominio.ejemplo.com/api
  try {
    if (Platform.isAndroid) return baseUrlLan;  // <IP_NAS>:8081/api
    return baseUrlLocal;                         // localhost:8081/api
  } catch (_) {
    return baseUrlLocal;
  }
}
```

Todos los endpoints con autenticación llevan el header:
```
Authorization: Bearer <JWT>
```

El JWT es un token firmado con HS512, válido 7 días, que contiene los claims:
- `sub`: email del usuario
- `rol`: USER | PREMIUM | ADMIN
- `usuarioId`: id numérico en la base de datos

---

## 11. Flujo de generación de tests con IA

Este es el flujo más complejo de la app, basado en el patrón **polling asíncrono**:

```
Usuario pulsa "Generar"
        │
        ▼
GenerateScreen.dart
POST /api/tests/generate
        │
        ▼
Backend crea SolicitudGeneracion (estado: "pendiente")
        │
        ▼
TestAsyncExecutor ejecuta en hilo separado:
  1. Construye el prompt con tema, oposición y dificultad
  2. Llama a Ollama (Qwen3-64k para PREMIUM, Qwen2.5-coder para FREE)
  3. Parsea el JSON con las preguntas
  4. Guarda en BD (TestEntity + Preguntas)
  5. Actualiza solicitud a estado: "completado"
        │
        ▼
TestsScreen.dart — Timer.periodic cada 3 segundos:
GET /api/tests/solicitud/{id}/estado
  · Si "pendiente/procesando" → sigue polling
  · Si "completado"           → actualiza card + notificación
  · Si "error"                → muestra mensaje + botón reintentar
        │
        ▼
Usuario pulsa el card completado
        │
        ▼
TestScreen.dart — carga preguntas:
GET /api/tests/{testId}
        │
        ▼
Usuario responde y envía:
PUT /api/tests/{testId}/respuestas
        │
        ▼
ResultadoTestScreen.dart — muestra corrección + explicaciones IA
```

---

## 12. Caché offline

`HiveCache` gestiona el almacenamiento local para cumplir el requisito RNF-10 (funcionalidad offline):

| Clave | Contenido | Uso |
|-------|-----------|-----|
| `convocatorias_box.ultima_lista` | Últimas 30 convocatorias | BOPAScreen en modo avión |
| `convocatorias_box.favoritos_lista` | Lista de favoritos | Acceso offline a guardados |
| `tests_box` | Tests completados | Revisión sin conexión |

`Hive` se inicializa en `main()` antes de `runApp()` para que esté disponible desde el primer frame.

---

## 13. Seguridad y RGPD

### Almacenamiento seguro del token
El JWT se guarda en `FlutterSecureStorage`, que utiliza:
- **Android**: Android Keystore System
- **iOS**: Keychain
- **Web**: `localStorage` cifrado (no recomendado para producción en web pública)

### Renovación automática del token
El interceptor de Dio comprueba antes de cada petición:
1. Si el token está expirado → logout y redirección a login.
2. Si caduca en menos de 24h → llama a `/api/auth/refresh` silenciosamente.

### Cumplimiento RGPD
| Derecho | Implementación |
|---------|---------------|
| **Art. 6** — Consentimiento | Checkbox RGPD obligatorio en el registro |
| **Art. 17** — Derecho al olvido | `PerfilScreen` → "Eliminar mi cuenta" → soft delete en 48h |
| **Art. 20** — Portabilidad | `PerfilScreen` → "Exportar mis datos" → JSON completo |

---

## 14. Requisitos cumplidos

| ID | Requisito | Pantalla |
|----|-----------|----------|
| RF-01 | Registro con email y contraseña | `LoginScreen` |
| RF-02 | Login con JWT de 7 días | `LoginScreen` → `AuthService` |
| RF-04 | Eliminación de cuenta RGPD Art. 17 | `PerfilScreen` |
| RF-05 | Notificaciones de tests completados | `TestsScreen` (polling) |
| RF-06 | Listar convocatorias con filtros | `BOPAScreen` |
| RF-07 | Búsqueda full-text BOPA | `BOPAScreen` (debounce) |
| RF-08 | Guardar convocatorias en favoritos | `BOPAScreen` |
| RF-09 | Generar tests con IA | `GenerateScreen` + `TestsScreen` |
| RF-10 | Presentar test con navegación | `TestScreen` |
| RF-11 | Corrección inmediata con explicación IA | `ResultadoTestScreen` |
| RF-12 | KPIs de progreso | `ProgresoScreen` |
| RF-13 | Gráfico de evolución | `ProgresoScreen` (fl_chart) |
| RF-14 | Historial de tests | `ProgresoScreen` |
| RF-15/16/17 | Panel administrador | `AdminDashboardScreen` |
| RF-21/22/23 | Banner publicitario | `AdBannerWidget` |
| RNF-10 | App funciona offline con caché | `HiveCache` |
| RNF-14 | JWT con renovación automática | `ApiService` interceptor |
| RNF-17 | Material Design 3 | `AppTheme` |
| RNF-26 | Consentimiento RGPD | `LoginScreen` (checkbox) |
| RNF-27 | Derecho al olvido | `PerfilScreen` |
| RNF-28 | Portabilidad JSON | `PerfilScreen` |

---

*Desarrollado como Trabajo de Fin de Grado — DAM · DAM · Asturias · 2026*
