import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../cache/hive_cache.dart';
import '../models/solicitud_generacion.dart';
import '../widgets/app_toast.dart';

const _naranja    = Color(0xFFFF6B00);
const _naranjaOsc = Color(0xFFE55A00);
const _fondo      = Color(0xFFF5F5F5);

class GenerateScreen extends StatefulWidget {
  const GenerateScreen({super.key});
  @override
  State<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends State<GenerateScreen>
    with SingleTickerProviderStateMixin {
  final _temaController = TextEditingController();
  String _oposicion = 'Auxiliar Administrativo';
  double _numPreguntas = 10;
  String _dificultad = 'Media';
  bool _isPremium = false;
  bool _isSubmitting = false;   // solo mientras se hace el POST inicial
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  final List<String> _oposicionesList = [
    'Auxiliar Administrativo', 'Administrativo', 'Celador',
    'Policía Local', 'Ordenanza',
  ];

  final Map<String, Color> _dificultadColor = {
    'Baja':  const Color(0xFF2E7D32),
    'Media': const Color(0xFFE65100),
    'Alta':  const Color(0xFFB00020),
  };

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _checkRole();
  }

  @override
  void dispose() {
    _temaController.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkRole() async {
    final premium = await AuthService.isPremium();
    if (mounted) setState(() => _isPremium = premium);
  }

  Future<void> _generarTest() async {
    if (_temaController.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      AppToast.show(context, 'Introduce un tema para generar el test', type: ToastType.warning);
      return;
    }
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      AppToast.show(context, 'Sin conexión. Comprueba tu red', type: ToastType.error);
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);
    try {
      final solicitud = SolicitudGeneracion(
        id: 0, oposicion: _oposicion,
        tema: _temaController.text.trim(),
        numPreguntas: _numPreguntas.toInt(),
        dificultad: _dificultad,
        estadoEnum: EstadoSolicitud.pendiente,
        fechaSolicitud: DateTime.now().toIso8601String(),
      );
      await ApiService.crearSolicitud(solicitud: solicitud);
      // ── UX MEJORADA: volver inmediatamente a la pestaña Tests
      // El polling lo gestiona TestsScreen, que ya tiene el widget de progreso
      if (mounted) {
        HapticFeedback.heavyImpact();
        AppToast.show(context,
          'Test en cola — la IA está generando las preguntas',
          type: ToastType.success,
          duration: const Duration(seconds: 3),
        );
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) context.pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppToast.show(context, 'Error: $e', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        title: const Text('Generar Test con IA'),
        backgroundColor: _naranja,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _PremiumBadge(isPremium: _isPremium),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionLabel(icon: Icons.work_outline_rounded, text: 'Tipo de oposición'),
                const SizedBox(height: 8),
                _OposicionSelector(value: _oposicion, options: _oposicionesList,
                    onChanged: (val) { HapticFeedback.selectionClick(); setState(() => _oposicion = val!); }),
                const SizedBox(height: 24),
                _SectionLabel(icon: Icons.menu_book_rounded, text: 'Tema a estudiar'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _temaController,
                  style: const TextStyle(color: Colors.black87, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Ej: Tráfico y Movilidad Urbana',
                    prefixIcon: const Icon(Icons.book_rounded, color: _naranja),
                    filled: true, fillColor: const Color(0xFFFFF3E0),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFFFCC80), width: 1.5)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _naranja, width: 2)),
                  ),
                  onTap: () => HapticFeedback.selectionClick(),
                ),
                const SizedBox(height: 28),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  _SectionLabel(icon: Icons.format_list_numbered_rounded, text: 'Nº de preguntas'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: _naranja, borderRadius: BorderRadius.circular(20)),
                    child: Text('${_numPreguntas.toInt()}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                  ),
                ]),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: _naranja, inactiveTrackColor: const Color(0xFFFFCC80),
                    thumbColor: _naranja, overlayColor: _naranja.withOpacity(0.15),
                    trackHeight: 6, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                  ),
                  child: Slider(value: _numPreguntas, min: 5, max: 20, divisions: 3,
                      label: _numPreguntas.toInt().toString(),
                      onChanged: (val) { HapticFeedback.selectionClick(); setState(() => _numPreguntas = val); }),
                ),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['5', '10', '15', '20']
                        .map((n) => Text(n, style: TextStyle(fontSize: 11, color: Colors.grey.shade500))).toList()),
                const SizedBox(height: 28),
                _SectionLabel(icon: Icons.trending_up_rounded, text: 'Dificultad'),
                const SizedBox(height: 10),
                Row(
                  children: ['Baja', 'Media', 'Alta'].map((df) {
                    final active = _dificultad == df;
                    final color = _dificultadColor[df]!;
                    return Expanded(child: GestureDetector(
                      onTap: () { HapticFeedback.selectionClick(); setState(() => _dificultad = df); },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: active ? color : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: active ? color : const Color(0xFFE0E0E0), width: active ? 2 : 1),
                          boxShadow: active ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
                        ),
                        child: Column(children: [
                          Icon(df == 'Baja' ? Icons.sentiment_satisfied_rounded : df == 'Media' ? Icons.sentiment_neutral_rounded : Icons.sentiment_very_dissatisfied_rounded,
                              color: active ? Colors.white : color, size: 26),
                          const SizedBox(height: 4),
                          Text(df, style: TextStyle(color: active ? Colors.white : color, fontWeight: FontWeight.w700, fontSize: 13)),
                        ]),
                      ),
                    ));
                  }).toList(),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isPremium ? const Color(0xFFFFF3E0) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _isPremium ? _naranja : Colors.grey.shade300),
                  ),
                  child: Row(children: [
                    Icon(_isPremium ? Icons.auto_awesome_rounded : Icons.memory_rounded,
                        color: _isPremium ? _naranja : Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_isPremium ? 'Modelo avanzado activo' : 'Modelo estándar',
                          style: TextStyle(fontWeight: FontWeight.w700,
                              color: _isPremium ? _naranjaOsc : Colors.grey.shade700)),
                      Text(_isPremium ? 'Qwen2.5 14B — Mayor precisión' : 'Qwen2.5 7B — Activa Premium para más',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ])),
                  ]),
                ),
              ],
            ),
          ),
          Positioned(
            left: 20, right: 20, bottom: 24,
            child: ScaleTransition(
              scale: _pulseAnim,
              child: SizedBox(
                height: 58,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _generarTest,
                  icon: _isSubmitting
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Icon(Icons.auto_awesome_rounded, size: 22),
                  label: Text(_isSubmitting ? 'Enviando...' : 'GENERAR TEST',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _naranja,
                    disabledBackgroundColor: _naranja.withOpacity(0.4),
                    foregroundColor: Colors.white, elevation: 6,
                    shadowColor: _naranja.withOpacity(0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets auxiliares de GenerateScreen ──────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final IconData icon; final String text;
  const _SectionLabel({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: _naranja), const SizedBox(width: 6),
    Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black87)),
  ]);
}

class _PremiumBadge extends StatelessWidget {
  final bool isPremium;
  const _PremiumBadge({required this.isPremium});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: isPremium ? Colors.amber.shade700 : Colors.white.withOpacity(0.3),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.5)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(isPremium ? Icons.auto_awesome : Icons.lock_open_rounded, size: 13, color: Colors.white),
      const SizedBox(width: 4),
      Text(isPremium ? 'PREMIUM' : 'FREE',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
    ]),
  );
}

class _OposicionSelector extends StatelessWidget {
  final String value; final List<String> options; final ValueChanged<String?> onChanged;
  const _OposicionSelector({required this.value, required this.options, required this.onChanged});
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    value: value,
    decoration: InputDecoration(
      prefixIcon: const Icon(Icons.work_outline_rounded, color: _naranja),
      filled: true, fillColor: const Color(0xFFFFF3E0),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFFCC80), width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _naranja, width: 2)),
    ),
    dropdownColor: Colors.white,
    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _naranja),
    style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
    items: options.map((op) => DropdownMenuItem(value: op, child: Text(op))).toList(),
    onChanged: onChanged,
  );
}
