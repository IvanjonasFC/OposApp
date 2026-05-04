import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'bopa_screen.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/notificacion.dart';
import 'tests_screen.dart';
import 'progreso_screen.dart';
import '../widgets/app_toast.dart';
import '../widgets/ad_banner_widget.dart';

const _naranja     = Color(0xFFFF6B00);
const _naranjaOsc  = Color(0xFFE55A00);
const _fondo       = Color(0xFFF5F5F5);

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isAdmin = false;
  int _badgeCount = 0;
  late AnimationController _fabAnim;

  // GlobalKey<TestsScreenState> — State PÚBLICO → acceso directo a cargarHistorial()
  final GlobalKey<TestsScreenState> _testsKey = GlobalKey<TestsScreenState>();
  final GlobalKey<ProgresoScreenState> _progresoKey = GlobalKey<ProgresoScreenState>();

  late final List<Widget> _screens = [
    BOPAScreen(),
    TestsScreen(key: _testsKey, onTestCompletado: _onTestCompletado),
    ProgresoScreen(key: _progresoKey),
  ];

  final List<String> _titles = ['Convocatorias BOPA', 'Tests con IA', 'Mi Progreso'];
  final List<IconData> _icons = [Icons.article_rounded, Icons.psychology_rounded, Icons.bar_chart_rounded];

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))..forward();
    _checkRole();
    _cargarBadge();
  }

  @override
  void dispose() { _fabAnim.dispose(); super.dispose(); }

  Future<void> _checkRole() async {
    final isAdmin = await AuthService.isAdmin();
    if (mounted) setState(() => _isAdmin = isAdmin);
  }

  Future<void> _cargarBadge() async {
    try {
      final count = await ApiService.getNotificacionesBadge();
      if (mounted) setState(() => _badgeCount = count);
    } catch (_) {}
  }

  /// Llamado por TestsScreen cuando el polling detecta un test completado.
  /// El backend ya habrá creado la notificación en ese momento → refrescamos el badge.
  void _onTestCompletado() {
    // Pequeño delay para dar tiempo al backend a persistir la notificación
    Future.delayed(const Duration(milliseconds: 800), _cargarBadge);
  }

  Future<void> _abrirNotificaciones() async {
    HapticFeedback.lightImpact();
    try {
      final notificaciones = await ApiService.getNotificaciones();
      if (!mounted) return;
      showModalBottomSheet(
        context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
        builder: (_) => _NotificacionesSheet(
          notificacionesIniciales: notificaciones,
          onMarcarTodas: () async {
            await ApiService.marcarTodasLeidas();
            if (mounted) setState(() => _badgeCount = 0);
          },
          onBadgeChanged: _cargarBadge,
        ),
      );
    } catch (e) {
      if (mounted) AppToast.show(context, 'Error: $e', type: ToastType.error);
    }
  }

  void _onTabTap(int index) {
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
    // Refrescar datos al cambiar de pestaña para mostrar info actualizada
    if (index == 1) {
      // Tests: recargar historial (detecta nuevos completados)
      _testsKey.currentState?.cargarHistorial();
    } else if (index == 2) {
      // Progreso: recargar estadísticas (tras completar tests)
      _progresoKey.currentState?.cargarEstadisticas();
    }
  }

  Future<void> _irAGenerar() async {
    HapticFeedback.heavyImpact();
    await context.push('/generate');
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    if (_currentIndex != 1) setState(() => _currentIndex = 1);
    _testsKey.currentState?.cargarHistorial();
    // También refrescar progreso por si se completó algún test
    _progresoKey.currentState?.cargarEstadisticas();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        backgroundColor: _naranja, foregroundColor: Colors.white,
        elevation: 0, centerTitle: true,
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
        actions: [
          Padding(padding: const EdgeInsets.only(right: 4),
            child: Stack(clipBehavior: Clip.none, children: [
              IconButton(icon: const Icon(Icons.notifications_rounded, color: Colors.white),
                  onPressed: _abrirNotificaciones),
              if (_badgeCount > 0) Positioned(right: 6, top: 8,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: const Color(0xFFB00020), borderRadius: BorderRadius.circular(8)),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(_badgeCount > 99 ? '99+' : '$_badgeCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                )),
            ])),
          if (_isAdmin) IconButton(
            icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white),
            onPressed: () { HapticFeedback.mediumImpact();
              context.push('/admin'); }),
          IconButton(icon: const Icon(Icons.account_circle_rounded, color: Colors.white),
              onPressed: () { HapticFeedback.lightImpact();
                context.push('/perfil'); }),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Banner publicitario — parte del bottomNavigationBar para que el FAB quede encima
          const AdBannerWidget(),
          _BottomBar(currentIndex: _currentIndex, icons: _icons,
              labels: const ['BOPA', 'Tests', 'Progreso'], onTap: _onTabTap),
        ],
      ),
      floatingActionButton: _currentIndex == 1
          ? ScaleTransition(scale: _fabAnim,
              child: FloatingActionButton.extended(
                onPressed: _irAGenerar,
                backgroundColor: _naranja, foregroundColor: Colors.white, elevation: 6,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Nuevo Test', style: TextStyle(fontWeight: FontWeight.w700)),
              ))
          : null,
    );
  }
}

// ── BottomBar ─────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final int currentIndex; final List<IconData> icons;
  final List<String> labels; final void Function(int) onTap;
  const _BottomBar({required this.currentIndex, required this.icons,
      required this.labels, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, -4))]),
    child: SafeArea(top: false, child: SizedBox(height: 64,
      child: Row(children: List.generate(icons.length, (i) {
        final active = i == currentIndex;
        return Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => onTap(i),
          child: AnimatedContainer(duration: const Duration(milliseconds: 200), curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: active ? 16 : 0, vertical: active ? 4 : 0),
                decoration: BoxDecoration(
                  color: active ? _naranja.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20)),
                child: Icon(icons[i], color: active ? _naranja : Colors.black38, size: active ? 24 : 22)),
              const SizedBox(height: 2),
              Text(labels[i], style: TextStyle(fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  color: active ? _naranja : Colors.black38)),
            ])),
        ));
      })),
    )),
  );
}

// ── Sheet notificaciones ──────────────────────────────────────────────────
class _NotificacionesSheet extends StatefulWidget {
  final List<Notificacion> notificacionesIniciales;
  final VoidCallback onMarcarTodas;
  final VoidCallback onBadgeChanged;

  const _NotificacionesSheet({
    required this.notificacionesIniciales,
    required this.onMarcarTodas,
    required this.onBadgeChanged,
  });

  @override
  State<_NotificacionesSheet> createState() => _NotificacionesSheetState();
}

class _NotificacionesSheetState extends State<_NotificacionesSheet> {
  late List<Notificacion> _notificaciones;

  @override
  void initState() {
    super.initState();
    _notificaciones = List.from(widget.notificacionesIniciales);
  }

  Future<void> _eliminarUna(Notificacion n) async {
    try {
      await ApiService.eliminarNotificacion(n.id);
      setState(() => _notificaciones.removeWhere((x) => x.id == n.id));
      widget.onBadgeChanged();
    } catch (_) {}
  }

  Future<void> _eliminarTodas() async {
    try {
      await ApiService.eliminarTodasNotificaciones();
      setState(() => _notificaciones.clear());
      widget.onBadgeChanged();
    } catch (_) {}
  }

  Future<void> _marcarTodas() async {
    HapticFeedback.lightImpact();
    widget.onMarcarTodas();
    setState(() {
      _notificaciones = _notificaciones.map((n) => n.comoLeida()).toList();
    });
    widget.onBadgeChanged();
  }

  _TipoConfig _configFor(TipoNotificacion tipo) {
    switch (tipo) {
      case TipoNotificacion.convocatoria:
        return _TipoConfig(Icons.article_outlined, const Color(0xFF1565C0), const Color(0xFFE3F2FD));
      case TipoNotificacion.test:
        return _TipoConfig(Icons.psychology_outlined, _naranja, _naranja.withOpacity(0.10));
      case TipoNotificacion.sistema:
        return _TipoConfig(Icons.info_outline_rounded, const Color(0xFF2E7D32), const Color(0xFFE8F5E9));
      default:
        return _TipoConfig(Icons.circle_notifications_outlined, const Color(0xFF6750A4), const Color(0xFFF3E5F5));
    }
  }

  @override
  Widget build(BuildContext context) {
    final noLeidas = _notificaciones.where((n) => !n.leida).length;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, ctrl) => Column(children: [
          // Handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 32, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Notificaciones',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3)),
                      if (noLeidas > 0)
                        Text('$noLeidas sin leer',
                            style: const TextStyle(
                                fontSize: 13,
                                color: _naranja,
                                fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                if (noLeidas > 0)
                  _ActionChip(label: 'Leídas', color: _naranja, onTap: _marcarTodas),
                if (noLeidas > 0 && _notificaciones.isNotEmpty)
                  const SizedBox(width: 8),
                if (_notificaciones.isNotEmpty)
                  _ActionChip(
                    label: 'Borrar todas',
                    color: const Color(0xFFB00020),
                    onTap: () { HapticFeedback.mediumImpact(); _eliminarTodas(); },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.grey.shade100),
          Expanded(
            child: _notificaciones.isEmpty
                ? _EmptyState()
                : ListView.builder(
                    controller: ctrl,
                    padding: const EdgeInsets.only(top: 4, bottom: 24),
                    itemCount: _notificaciones.length,
                    itemBuilder: (_, i) {
                      final n = _notificaciones[i];
                      return _NotifItem(
                        key: ValueKey(n.id),
                        notificacion: n,
                        config: _configFor(n.tipo),
                        onDismiss: () => _eliminarUna(n),
                        onDelete: () => _eliminarUna(n),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

// ── Chip de acción compacto ────────────────────────────────────────────────
class _ActionChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    ),
  );
}

// ── Estado vacío ───────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
          child: Icon(Icons.notifications_off_outlined, size: 34, color: Colors.grey.shade400),
        ),
        const SizedBox(height: 16),
        Text('Todo al día',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text('No tienes notificaciones nuevas',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
      ],
    ),
  );
}

// ── Item de notificación ───────────────────────────────────────────────────
class _NotifItem extends StatelessWidget {
  final Notificacion notificacion;
  final _TipoConfig config;
  final VoidCallback onDismiss;
  final VoidCallback onDelete;

  const _NotifItem({
    super.key,
    required this.notificacion,
    required this.config,
    required this.onDismiss,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final n = notificacion;
    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: const BoxDecoration(color: Color(0xFFB00020)),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 26),
            SizedBox(height: 2),
            Text('Eliminar',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      confirmDismiss: (_) async { HapticFeedback.mediumImpact(); return true; },
      onDismissed: (_) => onDismiss(),
      child: Material(
        color: n.leida ? Colors.transparent : _naranja.withOpacity(0.03),
        child: InkWell(
          onTap: () => HapticFeedback.selectionClick(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar circular por tipo
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: config.bgColor, shape: BoxShape.circle),
                  child: Icon(config.icon, color: config.iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                // Contenido
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(n.titulo,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: n.leida ? FontWeight.w500 : FontWeight.w700,
                                  color: Colors.black87)),
                        ),
                        const SizedBox(width: 8),
                        Text(_formatFecha(n.creadaEn),
                            style: TextStyle(
                                fontSize: 11,
                                color: n.leida ? Colors.grey.shade400 : _naranja,
                                fontWeight: n.leida ? FontWeight.w400 : FontWeight.w500)),
                      ]),
                      const SizedBox(height: 3),
                      Text(n.mensaje,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Dot no leída o botón cerrar si leída
                if (!n.leida)
                  Container(
                    width: 8, height: 8,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: const BoxDecoration(color: _naranja, shape: BoxShape.circle),
                  )
                else
                  GestureDetector(
                    onTap: onDelete,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(Icons.close_rounded, size: 16, color: Colors.grey.shade400),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatFecha(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Ahora mismo';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Config visual por tipo ─────────────────────────────────────────────────
class _TipoConfig {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  const _TipoConfig(this.icon, this.iconColor, this.bgColor);
}
