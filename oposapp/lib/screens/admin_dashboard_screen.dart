import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../models/dashboard_stats.dart';
import '../models/audit_log.dart';
import '../models/pregunta.dart';
import '../widgets/app_toast.dart';
import 'package:dio/dio.dart';

// ─── Colores OposApp ────────────────────────────────────────────────────────
const _kOrange = Color(0xFFFF6B00);
const _kOrangeDark = Color(0xFFE55A00);
const _kBg = Color(0xFFF5F5F5);
const _kSurface = Color(0xFFFFF3E0);
const _kSuccess = Color(0xFF4CAF50);
const _kError = Color(0xFFF44336);
const _kWarning = Color(0xFFFF9800);
const _kCardBg = Color(0xFFFFFFFF);

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _token;
  bool _loadingToken = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initToken();
  }

  Future<void> _initToken() async {
    final t = await AuthService.getToken();
    setState(() {
      _token = t;
      _loadingToken = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingToken) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kOrange)),
      );
    }
    if (_token == null || _token!.isEmpty) {
      return Scaffold(
        backgroundColor: _kBg,
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.lock_outline, size: 64, color: _kError),
            const SizedBox(height: 16),
            const Text('Sesión no encontrada.\nVuelve a iniciar sesión.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.black54)),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _kOrange),
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver', style: TextStyle(color: Colors.white)),
            )
          ]),
        ),
      );
    }
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Panel de Administración',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Recargar',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Resumen'),
            Tab(icon: Icon(Icons.people_outlined), text: 'Usuarios'),
            Tab(icon: Icon(Icons.history_outlined), text: 'Auditoría'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ResumenTab(token: _token!),
          _UsuariosTab(token: _token!),
          _AuditoriaTab(token: _token!),
        ],
      ),
    );
  }
}

// ─── TAB 1: RESUMEN ─────────────────────────────────────────────────────────
class _ResumenTab extends StatefulWidget {
  final String token;
  const _ResumenTab({required this.token});
  @override
  State<_ResumenTab> createState() => _ResumenTabState();
}

class _ResumenTabState extends State<_ResumenTab> {
  late Future<DashboardStats> _statsFuture;
  late Future<Map<String, dynamic>> _healthFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _statsFuture = AdminService.getStats(widget.token);
    _healthFuture = AdminService.getSystemHealth(widget.token);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _kOrange,
      onRefresh: () async => setState(() => _load()),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── KPIs ──
          const _SectionTitle(icon: Icons.bar_chart, label: 'Métricas Principales'),
          const SizedBox(height: 12),
          FutureBuilder<DashboardStats>(
            future: _statsFuture,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _kOrange));
              }
              if (snap.hasError) return _ErrorCard(message: snap.error.toString());
              final s = snap.data!;
              return Column(children: [
                Row(children: [
                  Expanded(child: _KpiCard(label: 'Usuarios', value: '${s.totalUsuarios}', icon: Icons.people, color: _kOrange)),
                  const SizedBox(width: 12),
                  Expanded(child: _KpiCard(label: 'Tests hoy', value: '${s.preguntasGeneradasHoy}', icon: Icons.psychology, color: _kSuccess)),
                  const SizedBox(width: 12),
                  Expanded(child: _KpiCard(label: 'Pendientes', value: '${s.solicitudesPendientes}', icon: Icons.pending_actions, color: Colors.amber[700]!)),
                ]),
              ]);
            },
          ),
          const SizedBox(height: 24),
          // ── Sistema Health ──
          const _SectionTitle(icon: Icons.monitor_heart_outlined, label: 'Estado del Sistema'),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, dynamic>>(
            future: _healthFuture,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: _kCardBg,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(color: _kOrange, strokeWidth: 2),
                    SizedBox(height: 12),
                    Text('Verificando servicios...', style: TextStyle(color: Colors.black45, fontSize: 13)),
                  ])),
                );
              }
              if (snap.hasError) return _ErrorCard(message: snap.error.toString());
              final h = snap.data!;
              final sistemaOk = h['sistema_ok'] == true;
              final ollamaOk = h['ollama_ok'] == true;
              final bdOk = h['bd_ok'] == true;
              final erroresIa = (h['errores_ia_24h'] ?? 0) as num;

              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Banner global rediseñado ──
                _ModernSystemBanner(ok: sistemaOk, health: h),
                const SizedBox(height: 16),
                // ── Grid de servicios: 3 cards útiles ──
                Row(children: [
                  Expanded(child: _ServiceCard(
                    icon: Icons.storage_rounded,
                    label: 'PostgreSQL',
                    status: bdOk ? 'Operativo' : 'Error',
                    detail: '${h['total_convocatorias'] ?? 0} convocatorias',
                    ok: bdOk,
                    gradient: bdOk
                      ? [const Color(0xFF43A047), const Color(0xFF66BB6A)]
                      : [_kError, Colors.red[300]!],
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _ServiceCard(
                    icon: Icons.psychology_rounded,
                    label: 'Ollama IA',
                    status: ollamaOk ? 'Online' : 'Offline',
                    detail: ollamaOk ? 'qwen3 · ${h['tests_ultimas_24h'] ?? 0} tests/24h' : 'Sin conexión',
                    ok: ollamaOk,
                    gradient: ollamaOk
                      ? [_kOrangeDark, _kOrange]
                      : [_kError, Colors.red[300]!],
                  )),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _ServiceCard(
                    icon: Icons.quiz_rounded,
                    label: 'Tests IA',
                    status: erroresIa == 0 ? 'Sin errores' : '$erroresIa error${erroresIa != 1 ? 'es' : ''}',
                    detail: 'Total: ${h['total_tests'] ?? 0} · Últimas 24h: ${h['tests_ultimas_24h'] ?? 0}',
                    ok: erroresIa == 0,
                    warning: erroresIa > 0,
                    gradient: erroresIa == 0
                      ? [const Color(0xFF7B1FA2), const Color(0xFFAB47BC)]
                      : [_kWarning, Colors.orange[300]!],
                  )),
                  const SizedBox(width: 12),
                  // BOPA: informativo — muestra actividad semanal de n8n
                  // nunca se marca como alerta (no podemos saber si n8n está corriendo)
                  Expanded(child: _BopaInfoCard(health: h)),
                ]),
                const SizedBox(height: 12),
                // ── Barra de actividad de usuarios ──
                _ActivityCard(health: h),
                const SizedBox(height: 8),
                // ── Timestamp ──
                if (h['timestamp'] != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.access_time, size: 11, color: Colors.black38),
                      const SizedBox(width: 4),
                      Text('Actualizado: ${_formatTimestamp(h['timestamp'].toString())}',
                          style: const TextStyle(fontSize: 11, color: Colors.black38)),
                    ]),
                  ),
              ]);
            },
          ),
        ]),
      ),
    );
  }

  String _formatTimestamp(String ts) {
    try {
      return ts.substring(0, 16).replaceAll('T', ' ');
    } catch (_) {
      return ts;
    }
  }
}

// ─── TAB 2: USUARIOS ────────────────────────────────────────────────────────
class _UsuariosTab extends StatefulWidget {
  final String token;
  const _UsuariosTab({required this.token});
  @override
  State<_UsuariosTab> createState() => _UsuariosTabState();
}

class _UsuariosTabState extends State<_UsuariosTab> {
  late Future<List<Map<String, dynamic>>> _usuariosFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _usuariosFuture = AdminService.getUsuarios(widget.token);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _kOrange,
      onRefresh: () async => setState(() => _load()),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _usuariosFuture,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _kOrange));
          }
          if (snap.hasError) return _ErrorCard(message: snap.error.toString());
          final users = snap.data ?? [];
          if (users.isEmpty) {
            return const Center(child: Text('No hay usuarios registrados.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) => _UserCard(
              user: users[i],
              token: widget.token,
              onChanged: () => setState(() => _load()),
            ),
          );
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final String token;
  final VoidCallback onChanged;
  const _UserCard({required this.user, required this.token, required this.onChanged});

  Color _rolColor(String rol) {
    switch (rol.toUpperCase()) {
      case 'ADMIN': return Colors.purple;
      case 'PREMIUM': return _kOrange;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rol = (user['rol'] ?? 'USER').toString();
    final activo = user['activo'] == true;
    final id = user['id'];
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: _kOrange.withOpacity(0.15),
              child: Text((user['username'] ?? '?').toString().substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: _kOrange, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user['username']?.toString() ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(user['email']?.toString() ?? '-',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _rolColor(rol).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(rol, style: TextStyle(
                  color: _rolColor(rol), fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _ActionChip(
              label: activo ? 'Desactivar' : 'Activar',
              icon: activo ? Icons.block : Icons.check_circle_outline,
              color: activo ? _kError : _kSuccess,
              onTap: () => _toggleEstado(context, id, !activo),
            ),
            const SizedBox(width: 8),
            _ActionChip(
              label: 'Cambiar rol',
              icon: Icons.manage_accounts_outlined,
              color: _kOrange,
              onTap: () => _showCambiarRol(context, id, rol),
            ),
            const SizedBox(width: 8),
            _ActionChip(
              label: 'Contraseña',
              icon: Icons.lock_reset_outlined,
              color: Colors.blueGrey,
              onTap: () => _showCambiarPassword(context, id),
            ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _toggleEstado(BuildContext ctx, dynamic id, bool nuevoEstado) async {
    try {
      await AdminService.cambiarEstado(token, id, nuevoEstado);
      if (ctx.mounted) {
        AppToast.show(ctx,
          nuevoEstado ? 'Cuenta activada' : 'Cuenta desactivada',
          type: nuevoEstado ? ToastType.success : ToastType.warning,
        );
        onChanged();
      }
    } catch (e) {
      if (ctx.mounted) AppToast.show(ctx, 'Error: $e', type: ToastType.error);
    }
  }

  void _showCambiarRol(BuildContext ctx, dynamic id, String rolActual) {
    String seleccionado = rolActual.toUpperCase();
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.manage_accounts, color: _kOrange),
          SizedBox(width: 8),
          Text('Cambiar Rol'),
        ]),
        content: StatefulBuilder(
          builder: (_, setLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            children: ['USER', 'PREMIUM', 'ADMIN'].map((r) => RadioListTile<String>(
              value: r,
              groupValue: seleccionado,
              activeColor: _kOrange,
              title: Text(r),
              onChanged: (v) => setLocal(() => seleccionado = v!),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kOrange),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await AdminService.cambiarRol(token, id, seleccionado);
                if (ctx.mounted) {
                  AppToast.show(ctx, 'Rol cambiado a $seleccionado', type: ToastType.success);
                  onChanged();
                }
              } catch (e) {
                if (ctx.mounted) AppToast.show(ctx, 'Error: $e', type: ToastType.error);
              }
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCambiarPassword(BuildContext ctx, dynamic id) {
    final ctrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.lock_reset, color: _kOrange),
          SizedBox(width: 8),
          Text('Nueva Contraseña'),
        ]),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Nueva contraseña (mín. 8 chars)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kOrange),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kOrange),
            onPressed: () async {
              if (ctrl.text.length < 8) {
                AppToast.show(dialogCtx, 'Mínimo 8 caracteres', type: ToastType.warning);
                return;
              }
              Navigator.pop(dialogCtx);
              try {
                await AdminService.cambiarPassword(token, id, ctrl.text);
                if (ctx.mounted) AppToast.show(ctx, 'Contraseña actualizada', type: ToastType.success);
              } catch (e) {
                if (ctx.mounted) AppToast.show(ctx, 'Error: $e', type: ToastType.error);
              }
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─── TAB 3: AUDITORÍA ───────────────────────────────────────────────────────
class _AuditoriaTab extends StatefulWidget {
  final String token;
  const _AuditoriaTab({required this.token});
  @override
  State<_AuditoriaTab> createState() => _AuditoriaTabState();
}

class _AuditoriaTabState extends State<_AuditoriaTab> {
  late Future<List<AuditLog>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _logsFuture = AdminService.getAuditLogs(widget.token);
  }

  Color _opColor(String op) {
    switch (op.toUpperCase()) {
      case 'LOGIN_OK':        return _kOrange;
      case 'LOGIN_FAIL':      return _kError;
      case 'REGISTRO':        return const Color(0xFF1E88E5);
      case 'TOKEN_REFRESH':   return Colors.blue[300]!;
      case 'TEST_GENERADO':   return const Color(0xFF7B1FA2);
      case 'TEST_COMPLETADO': return _kSuccess;
      case 'TEST_ERROR':      return _kError;
      case 'TEST_EVALUADO':   return const Color(0xFF00897B);
      case 'ROL_CAMBIADO':    return Colors.deepPurple;
      case 'CUENTA_ACTIVADA': return _kSuccess;
      case 'CUENTA_DESACTIVADA': return _kWarning;
      case 'PASSWORD_CAMBIADA': return Colors.blueGrey;
      case 'SOLICITUD_BAJA':  return _kError;
      case 'EXPORTACION_DATOS': return const Color(0xFF0097A7);
      case 'FAVORITO_GUARDADO': return _kOrange;
      case 'FAVORITO_ELIMINADO': return Colors.grey;
      case 'PERFIL_ACTUALIZADO': return const Color(0xFF43A047);
      case 'USUARIO_ELIMINADO': return Colors.red[900]!;
      case 'INSERT': return _kSuccess;
      case 'UPDATE': return Colors.amber[700]!;
      case 'DELETE': return _kError;
      default: return Colors.grey;
    }
  }

  IconData _opIcon(String op) {
    switch (op.toUpperCase()) {
      case 'LOGIN_OK':        return Icons.login_rounded;
      case 'LOGIN_FAIL':      return Icons.no_accounts_rounded;
      case 'REGISTRO':        return Icons.person_add_rounded;
      case 'TOKEN_REFRESH':   return Icons.refresh_rounded;
      case 'TEST_GENERADO':   return Icons.psychology_rounded;
      case 'TEST_COMPLETADO': return Icons.check_circle_rounded;
      case 'TEST_ERROR':      return Icons.error_rounded;
      case 'TEST_EVALUADO':   return Icons.grading_rounded;
      case 'ROL_CAMBIADO':    return Icons.manage_accounts_rounded;
      case 'CUENTA_ACTIVADA': return Icons.how_to_reg_rounded;
      case 'CUENTA_DESACTIVADA': return Icons.block_rounded;
      case 'PASSWORD_CAMBIADA': return Icons.lock_reset_rounded;
      case 'SOLICITUD_BAJA':  return Icons.delete_forever_rounded;
      case 'EXPORTACION_DATOS': return Icons.download_rounded;
      case 'FAVORITO_GUARDADO': return Icons.bookmark_added_rounded;
      case 'FAVORITO_ELIMINADO': return Icons.bookmark_remove_rounded;
      case 'PERFIL_ACTUALIZADO': return Icons.edit_rounded;
      case 'USUARIO_ELIMINADO': return Icons.person_remove_rounded;
      case 'INSERT': return Icons.add_circle_outline;
      case 'UPDATE': return Icons.edit_outlined;
      case 'DELETE': return Icons.delete_outline;
      default: return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _kOrange,
      onRefresh: () async => setState(() =>
          _logsFuture = AdminService.getAuditLogs(widget.token)),
      child: FutureBuilder<List<AuditLog>>(
        future: _logsFuture,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _kOrange));
          }
          if (snap.hasError) return _ErrorCard(message: snap.error.toString());
          final logs = snap.data ?? [];
          if (logs.isEmpty) {
            return const Center(child: Text('No hay registros de auditoría.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (ctx, i) {
              final log = logs[i];
              final color = _opColor(log.operacion);
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 1,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.15),
                    child: Icon(_opIcon(log.operacion), color: color, size: 20),
                  ),
                  title: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(log.operacion,
                          style: TextStyle(color: color,
                              fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(log.tabla,
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                        overflow: TextOverflow.ellipsis)),
                  ]),
                  subtitle: log.datosNuevos != null && log.datosNuevos!.isNotEmpty
                    ? Text(log.datosNuevos!,
                        style: const TextStyle(fontSize: 10, color: Colors.black38),
                        maxLines: 1, overflow: TextOverflow.ellipsis)
                    : Text('ID usuario: ${log.usuarioId ?? '-'}',
                        style: const TextStyle(fontSize: 10, color: Colors.black38)),
                  trailing: log.timestamp != null
                      ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(
                            '${log.timestamp!.hour.toString().padLeft(2, '0')}:${log.timestamp!.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            '${log.timestamp!.day}/${log.timestamp!.month}',
                            style: const TextStyle(fontSize: 11, color: Colors.black45),
                          ),
                        ])
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Card informativa BOPA — nunca alerta ────────────────────────────────────
/// Muestra la actividad semanal del scraping n8n de forma informativa.
/// A diferencia de Ollama/BD, el estado del BOPA nunca se marca como error
/// porque no hay forma de saber si n8n está corriendo desde el backend.
/// Solo indica si se añadieron convocatorias en los últimos 7 días.
class _BopaInfoCard extends StatelessWidget {
  final Map<String, dynamic> health;
  const _BopaInfoCard({required this.health});

  @override
  Widget build(BuildContext context) {
    final semanales = (health['convocatorias_ultima_semana'] ?? 0) as num;
    final total = (health['total_convocatorias'] ?? 0) as num;
    final hayActividad = semanales > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hayActividad
            ? [const Color(0xFF1565C0), const Color(0xFF1E88E5)]
            : [const Color(0xFF546E7A), const Color(0xFF78909C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: (hayActividad ? const Color(0xFF1565C0) : const Color(0xFF546E7A)).withValues(alpha: 0.3),
          blurRadius: 10, offset: const Offset(0, 4),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.newspaper_rounded, color: Colors.white, size: 18),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              hayActividad ? '+$semanales esta semana' : 'Sin novedades',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        const Text('BOPA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 2),
        Text(
          '$total convocatorias totales',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10),
        ),
        const SizedBox(height: 4),
        Text(
          hayActividad ? 'n8n activo — scraping semanal OK' : 'n8n gestionado externamente',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 9),
        ),
      ]),
    );
  }
}

// ─── WIDGETS COMPARTIDOS ─────────────────────────────────────────────────────

// Banner global moderno con gradiente
class _ModernSystemBanner extends StatelessWidget {
  final bool ok;
  final Map<String, dynamic> health;
  const _ModernSystemBanner({required this.ok, required this.health});

  @override
  Widget build(BuildContext context) {
    final services = [
      health['bd_ok'] == true,
      health['ollama_ok'] == true,
    ];
    final okCount = services.where((s) => s).length;
    final serviciosTotal = services.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: ok
              ? [const Color(0xFF2E7D32), const Color(0xFF43A047)]
              : [const Color(0xFFC62828), const Color(0xFFE53935)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (ok ? _kSuccess : _kError).withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            ok ? Icons.verified_rounded : Icons.warning_amber_rounded,
            color: Colors.white, size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            ok ? 'Sistema Totalmente Operativo' : 'Sistema con Alertas',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            '$okCount/$serviciosTotal servicios funcionando correctamente',
            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
          ),
        ])),
        // Indicador pulsante
        _PulsingDot(color: Colors.white),
      ]),
    );
  }
}

// Punto pulsante animado
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 12, height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withOpacity(_anim.value),
          boxShadow: [BoxShadow(color: widget.color.withOpacity(0.5), blurRadius: 8 * _anim.value)],
        ),
      ),
    );
  }
}

// Tarjeta de servicio con gradiente
class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String status;
  final String detail;
  final bool ok;
  final bool warning;
  final List<Color> gradient;

  const _ServiceCard({
    required this.icon, required this.label, required this.status,
    required this.detail, required this.ok, required this.gradient,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (ok ? (warning ? _kWarning : _kSuccess) : _kError).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ok ? (warning ? _kWarning : _kSuccess) : _kError,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                status,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: ok ? (warning ? _kWarning : _kSuccess) : _kError,
                ),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
        const SizedBox(height: 4),
        Text(detail, style: const TextStyle(fontSize: 11, color: Colors.black45), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

// Tarjeta de actividad de usuarios
class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> health;
  const _ActivityCard({required this.health});

  @override
  Widget build(BuildContext context) {
    final activos = (health['usuarios_activos'] ?? 0) as num;
    final logins = (health['logins_ultimas_24h'] ?? 0) as num;
    final convSemana = (health['convocatorias_ultima_semana'] ?? 0) as num;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.show_chart_rounded, color: _kOrange, size: 16),
          SizedBox(width: 6),
          Text('Actividad Reciente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _MiniStat(label: 'Usuarios activos', value: '$activos', icon: Icons.people_rounded, color: _kOrange)),
          const SizedBox(width: 8),
          Expanded(child: _MiniStat(label: 'Logins 24h', value: '$logins', icon: Icons.login_rounded, color: Colors.blue)),
          const SizedBox(width: 8),
          Expanded(child: _MiniStat(label: 'BOPA esta semana', value: '$convSemana', icon: Icons.article_rounded, color: Colors.purple)),
        ]),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black45), textAlign: TextAlign.center, maxLines: 2),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: _kOrange, size: 20),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
    ]);
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.label, required this.value,
      required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      color: _kSurface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
        ]),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip({required this.label, required this.icon,
      required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color,
              fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, color: _kError, size: 48),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54)),
            ]),
          ),
        ),
      ),
    );
  }
}
