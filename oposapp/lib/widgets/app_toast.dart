import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Sistema de toast premium de OposApp.
/// Reemplaza todos los SnackBar estándar de Material con un overlay
/// personalizado: animación slide+fade, icono SVG, botón de acción opcional.
///
/// Uso básico:
///   AppToast.show(context, 'Mensaje');
///   AppToast.show(context, 'Error', type: ToastType.error);
///   AppToast.show(context, 'Éxito', type: ToastType.success,
///       actionLabel: 'DESHACER', onAction: () { ... });
enum ToastType { success, error, warning, info }

class AppToast {
  static OverlayEntry? _current;

  static void show(
    BuildContext context,
    String mensaje, {
    ToastType type = ToastType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Cierra el toast anterior si lo hay
    _current?.remove();
    _current = null;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _AppToastWidget(
        mensaje: mensaje,
        type: type,
        actionLabel: actionLabel,
        onAction: onAction != null
            ? () { entry.remove(); _current = null; onAction(); }
            : null,
        onDismiss: () { entry.remove(); _current = null; },
      ),
    );

    _current = entry;
    overlay.insert(entry);

    Future.delayed(duration, () {
      if (entry.mounted) { entry.remove(); _current = null; }
    });
  }
}

// ─── Widget interno del toast ───────────────────────────────────────────
class _AppToastWidget extends StatefulWidget {
  final String mensaje;
  final ToastType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  const _AppToastWidget({
    required this.mensaje,
    required this.type,
    this.actionLabel,
    this.onAction,
    required this.onDismiss,
  });

  @override
  State<_AppToastWidget> createState() => _AppToastWidgetState();
}

class _AppToastWidgetState extends State<_AppToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 360));
    _slide = Tween<Offset>(begin: const Offset(0, 1.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _cerrar(VoidCallback cb) async {
    if (_ctrl.isAnimating) return;
    await _ctrl.reverse();
    cb();
  }

  // ── Paleta por tipo ───────────────────────────────────────────────────
  // Success: verde #4CAF50 de la guía de estilos (Entrega 6)
  // Error:   rojo oscuro
  // Warning: ámbar oscuro
  // Info:    azul oscuro
  Color get _bg {
    switch (widget.type) {
      case ToastType.success: return const Color(0xFF4CAF50);
      case ToastType.error:   return const Color(0xFF3D1C1C);
      case ToastType.warning: return const Color(0xFF3D2E0A);
      case ToastType.info:    return const Color(0xFF1C2B3D);
    }
  }

  Color get _accent {
    switch (widget.type) {
      case ToastType.success: return Colors.white;
      case ToastType.error:   return const Color(0xFFEF5350);
      case ToastType.warning: return const Color(0xFFFF9800);
      case ToastType.info:    return const Color(0xFF42A5F5);
    }
  }

  // Color del texto — blanco para fondos oscuros, blanco también sobre el verde
  Color get _textColor => Colors.white;

  // Color del fondo del icono
  Color get _iconBg {
    switch (widget.type) {
      case ToastType.success: return Colors.white.withOpacity(0.22);
      case ToastType.error:   return const Color(0xFFEF5350).withOpacity(0.18);
      case ToastType.warning: return const Color(0xFFFF9800).withOpacity(0.18);
      case ToastType.info:    return const Color(0xFF42A5F5).withOpacity(0.18);
    }
  }

  // Color del borde
  Color get _borderColor {
    switch (widget.type) {
      case ToastType.success: return Colors.white.withOpacity(0.30);
      default:                return _accent.withOpacity(0.25);
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case ToastType.success: return Icons.check_circle_outline_rounded;
      case ToastType.error:   return Icons.error_outline_rounded;
      case ToastType.warning: return Icons.warning_amber_rounded;
      case ToastType.info:    return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16, right: 16,
      bottom: 32 + MediaQuery.of(context).padding.bottom,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) > 150) _cerrar(widget.onDismiss);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _borderColor),
                ),
                padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
                child: Row(children: [
                  // Icono
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _iconBg,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(child: Icon(_icon, color: _accent, size: 22)),
                  ),
                  const SizedBox(width: 12),
                  // Mensaje
                  Expanded(
                    child: Text(
                      widget.mensaje,
                      style: TextStyle(
                        color: _textColor, fontSize: 13.5,
                        fontWeight: FontWeight.w600, height: 1.35,
                      ),
                    ),
                  ),
                  // Botón de acción opcional
                  if (widget.actionLabel != null && widget.onAction != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _cerrar(widget.onAction!),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B00),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          widget.actionLabel!,
                          style: const TextStyle(
                            color: Colors.white, fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
