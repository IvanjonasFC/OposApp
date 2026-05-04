import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import '../models/solicitud_generacion.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_toast.dart';

const _naranja    = Color(0xFFFF6B00);
const _naranjaOsc = Color(0xFFE55A00);
const _fondo      = Color(0xFFF5F5F5);

class TestsScreen extends StatefulWidget {
  /// Callback que HomeScreen inyecta para que TestsScreen pueda
  /// incrementar el badge de notificaciones cuando un test se completa.
  final VoidCallback? onTestCompletado;

  const TestsScreen({super.key, this.onTestCompletado});
  @override
  TestsScreenState createState() => TestsScreenState();
}

class TestsScreenState extends State<TestsScreen> {
  final List<SolicitudGeneracion> _solicitudes = [];
  bool _isLoading = true;
  final Map<int, Timer> _pollingTimers = {};

  @override
  void initState() {
    super.initState();
    cargarHistorial();
  }

  @override
  void dispose() {
    for (final t in _pollingTimers.values) t.cancel();
    super.dispose();
  }

  /// Público — llamado desde HomeScreen via GlobalKey tras volver de GenerateScreen
  Future<void> cargarHistorial() async {
    setState(() => _isLoading = true);
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('No autenticado');
      final solicitudes = await ApiService.getHistorialSolicitudes();
      if (!mounted) return;
      setState(() {
        _solicitudes.clear();
        _solicitudes.addAll(solicitudes);
        _isLoading = false;
      });
      for (final s in solicitudes) {
        if (s.id != null && (s.estado == 'pendiente' || s.estado == 'procesando')) {
          _arrancarPolling(s.id!);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppToast.show(context, 'Error al cargar tests: $e', type: ToastType.error);
    }
  }

  void _arrancarPolling(int id) {
    _pollingTimers[id]?.cancel();
    _pollingTimers[id] = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        // /estado solo devuelve {solicitudId, estado, testId, fechaCompletado}
        // Mergeamos sobre la solicitud existente para no perder tema/oposicion/etc.
        final estadoActualizado = await ApiService.verificarSolicitud(id);
        if (!mounted) { timer.cancel(); return; }
        setState(() {
          final idx = _solicitudes.indexWhere((s) => s.id == id);
          if (idx != -1) {
            _solicitudes[idx] = _solicitudes[idx].copyWithEstado(estadoActualizado);
          }
        });
        if (estadoActualizado.estado == 'completado' || estadoActualizado.estado == 'error') {
          timer.cancel();
          _pollingTimers.remove(id);
          if (estadoActualizado.estado == 'completado' && estadoActualizado.testId != null) {
            HapticFeedback.heavyImpact();
            // Recargar la lista completa desde el servidor para que quede
            // ordenada por fecha DESC (el nuevo queda el primero)
            await cargarHistorial();
            final idx = _solicitudes.indexWhere((s) => s.id == id);
            if (idx != -1) _mostrarSnackTestListo(_solicitudes[idx]);
            // Incrementar badge en HomeScreen: el backend ya creó la notificación
            widget.onTestCompletado?.call();
          }
        }
      } catch (_) {}
    });
  }

  void _mostrarSnackTestListo(SolicitudGeneracion s) {
    if (!mounted) return;

    // Overlay personalizado — más premium que el SnackBar estándar de Material
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(builder: (_) => _ToastTestListo(
      solicitud: s,
      onEmpezar: () {
        entry.remove();
        _abrirTest(s);
      },
      onDismiss: () => entry.remove(),
    ));

    overlay.insert(entry);

    // Auto-dismiss tras 4 segundos si el usuario no actúa
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
  }

  void _abrirTest(SolicitudGeneracion solicitud) {
    final testId = solicitud.testId;
    if (solicitud.estado != 'completado' || testId == null) return;
    HapticFeedback.mediumImpact();
    context.push('/test/$testId').then((_) => cargarHistorial());
  }

  Future<void> _eliminarSolicitud(SolicitudGeneracion solicitud) async {
    final id = solicitud.id;
    if (id == null) return;
    HapticFeedback.mediumImpact();
    try {
      await ApiService.deleteSolicitud(id);
      setState(() => _solicitudes.removeWhere((s) => s.id == id));
      if (mounted) AppToast.show(context, 'Test eliminado', type: ToastType.info);
    } catch (e) {
      if (mounted) AppToast.show(context, 'Error al eliminar: $e', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _naranja,
      onRefresh: cargarHistorial,
      child: _isLoading
          ? _buildSkeleton()
          : _solicitudes.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: _solicitudes.length,
                  itemBuilder: (_, i) => _TestCard(
                    solicitud: _solicitudes[i],
                    onTap: () => _abrirTest(_solicitudes[i]),
                    onDelete: () => _eliminarSolicitud(_solicitudes[i]),
                  ),
                ),
    );
  }

  Widget _buildSkeleton() => ListView.builder(
    padding: const EdgeInsets.all(12), itemCount: 4,
    itemBuilder: (_, __) => Shimmer.fromColors(
      baseColor: Colors.grey[200]!, highlightColor: Colors.grey[50]!,
      child: Container(margin: const EdgeInsets.only(bottom: 10), height: 90,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
    ),
  );

  Widget _buildEmpty() => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: constraints.maxHeight > 0 ? constraints.maxHeight : 400,
        child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: _naranja.withOpacity(0.08), shape: BoxShape.circle),
              child: Icon(Icons.psychology_outlined, size: 64, color: _naranja.withOpacity(0.4))),
            const SizedBox(height: 20),
            const Text('Sin tests generados',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black54)),
            const SizedBox(height: 8),
            Text('Pulsa "Nuevo Test" para generar uno con IA',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          ]),
        ),
      ),
    ),
  );
}

// ── Toast premium "test listo" ────────────────────────────────────────────
class _ToastTestListo extends StatefulWidget {
  final SolicitudGeneracion solicitud;
  final VoidCallback onEmpezar;
  final VoidCallback onDismiss;

  const _ToastTestListo({
    required this.solicitud,
    required this.onEmpezar,
    required this.onDismiss,
  });

  @override
  State<_ToastTestListo> createState() => _ToastTestListoState();
}

class _ToastTestListoState extends State<_ToastTestListo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _slide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _cerrar(VoidCallback cb) async {
    await _ctrl.reverse();
    cb();
  }

  @override
  Widget build(BuildContext context) {
    final meta =
        '${widget.solicitud.oposicion} · ${widget.solicitud.numPreguntas} preguntas · ${widget.solicitud.dificultad}';

    return Positioned(
      left: 16, right: 16, bottom: 32 + MediaQuery.of(context).padding.bottom,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onVerticalDragEnd: (d) {
                if (d.primaryVelocity != null && d.primaryVelocity! > 200) {
                  _cerrar(widget.onDismiss);
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.30)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                child: Row(children: [
                  // Icono circular
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(child: _CheckIcon()),
                  ),
                  const SizedBox(width: 14),
                  // Texto
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Test listo',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12)),
                    ],
                  )),
                  const SizedBox(width: 10),
                  // Botón naranja OposApp
                  GestureDetector(
                    onTap: () => _cerrar(widget.onEmpezar),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B00),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Text('Empezar',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Checkmark SVG limpio (sin emoji)
class _CheckIcon extends StatelessWidget {
  const _CheckIcon();
  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(22, 22),
        painter: _CheckPainter(),
      );
}

class _CheckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final circlePaint = Paint()
      ..color = Colors.transparent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Círculo exterior blanco
    circlePaint.color = Colors.white;
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), size.width / 2 - 1, circlePaint);

    // Checkmark
    final path = Path()
      ..moveTo(size.width * 0.22, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.72)
      ..lineTo(size.width * 0.78, size.height * 0.34);
    canvas.drawPath(path, checkPaint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Card premium ──────────────────────────────────────────────────────────
class _TestCard extends StatelessWidget {
  final SolicitudGeneracion solicitud;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _TestCard({required this.solicitud, required this.onTap, required this.onDelete});

  bool get _enCurso    => solicitud.estado == 'pendiente' || solicitud.estado == 'procesando';
  bool get _completado => solicitud.estado == 'completado';
  bool get _realizado  => _completado && solicitud.vecesRealizado > 0;

  Color get _accentColor {
    if (solicitud.estado == 'error') return const Color(0xFFB00020);
    if (_enCurso) return _naranja;
    if (_realizado) return _naranja;           // realizado → naranja
    return const Color(0xFF2E7D32);            // listo pero no realizado → verde
  }

  IconData get _icon {
    if (solicitud.estado == 'error') return Icons.error_rounded;
    if (_enCurso) return Icons.hourglass_top_rounded;
    if (_realizado) return Icons.replay_rounded;       // icono "repetir" naranja
    return Icons.check_circle_outline_rounded;
  }

  // Color semáforo para la nota
  Color _colorNota(double pct) {
    if (pct >= 70) return const Color(0xFF2E7D32);
    if (pct >= 50) return const Color(0xFFE65100);
    return const Color(0xFFB00020);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _realizado ? const Color(0xFFFFF3EB) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: _realizado
            ? Border.all(color: _naranja.withOpacity(0.25), width: 1)
            : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _completado ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          splashColor: _naranja.withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(children: [
              // ── Icono izquierda ──
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _enCurso
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: _naranja))
                    : Icon(_icon, color: _accentColor, size: 28),
              ),
              const SizedBox(width: 14),
              // ── Contenido central ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Título
                    Text(solicitud.tema,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87)),
                    const SizedBox(height: 3),
                    // Meta
                    Text(
                      '${solicitud.oposicion} · ${solicitud.numPreguntas} preguntas · ${solicitud.dificultad}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    // Chip de estado + badges de nota/veces
                    Row(children: [
                      _buildChip(),
                      if (_realizado && solicitud.ultimaNota != null) ...[
                        const SizedBox(width: 6),
                        _NotaBadge(pct: solicitud.ultimaNota!, colorFn: _colorNota),
                      ],
                      if (_realizado && solicitud.vecesRealizado > 1) ...[
                        const SizedBox(width: 6),
                        _VecesBadge(veces: solicitud.vecesRealizado),
                      ],
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // ── Trailing ──
              if (solicitud.estado == 'error' || solicitud.estado == 'pendiente')
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFB00020), size: 22),
                  onPressed: onDelete,
                  tooltip: 'Eliminar',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              else if (_completado)
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade300),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildChip() {
    if (_enCurso) return _chip(
        color: _naranja,
        text: solicitud.estado == 'pendiente' ? 'En cola...' : 'IA generando...',
        dot: true);
    if (_completado) {
      if (_realizado) return _chip(color: _naranja, text: 'Realizado · Toca para repetir');
      return _chip(color: const Color(0xFF2E7D32), text: 'LISTO — Toca para empezar');
    }
    return _chip(color: const Color(0xFFB00020), text: 'ERROR — Intenta de nuevo');
  }

  Widget _chip({required Color color, required String text, bool dot = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(20),
      border: dot ? Border.all(color: color.withOpacity(0.3)) : null,
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (dot) ...[
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
      ],
      Flexible(child: Text(text,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700))),
    ]),
  );
}

// ── Badge nota último intento ──────────────────────────────────────────────
class _NotaBadge extends StatelessWidget {
  final double pct;
  final Color Function(double) colorFn;
  const _NotaBadge({required this.pct, required this.colorFn});

  @override
  Widget build(BuildContext context) {
    final color = colorFn(pct);
    final nota = (pct / 10).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.star_rounded, size: 13, color: color),
        const SizedBox(width: 4),
        Text('Nota: ',
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.8), fontWeight: FontWeight.w500)),
        Text('$nota/10',
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ── Badge contador de veces realizado ─────────────────────────────────────
class _VecesBadge extends StatelessWidget {
  final int veces;
  const _VecesBadge({required this.veces});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFF6750A4).withOpacity(0.10),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.repeat_rounded, size: 11, color: Color(0xFF6750A4)),
      const SizedBox(width: 3),
      Text('${veces}x',
          style: const TextStyle(
              fontSize: 11, color: Color(0xFF6750A4), fontWeight: FontWeight.w700)),
    ]),
  );
}
