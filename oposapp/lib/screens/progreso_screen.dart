import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../models/estadisticas.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_toast.dart';

const _naranja    = Color(0xFFFF6B00);
const _naranjaOsc = Color(0xFFE55A00);
const _fondo      = Color(0xFFF5F5F5);

/// Paleta y helpers de avatar â€” idénticos a PerfilScreen para coherencia visual.
const _avatarPalette = [
  Color(0xFFFF6B00), Color(0xFF1565C0), Color(0xFF2E7D32),
  Color(0xFF6A1B9A), Color(0xFF00838F), Color(0xFFC62828),
  Color(0xFF4527A0), Color(0xFF00695C), Color(0xFFAD1457),
  Color(0xFFE65100),
];
const _avatarIcons = [
  Icons.school_rounded, Icons.menu_book_rounded, Icons.emoji_events_rounded,
  Icons.psychology_rounded, Icons.star_rounded, Icons.local_library_rounded,
  Icons.workspace_premium_rounded, Icons.lightbulb_rounded,
  Icons.military_tech_rounded, Icons.auto_awesome_rounded,
];
int _hashEmail(String email) {
  int h = 5381;
  for (final c in email.codeUnits) { h = ((h << 5) + h + c) & 0x7FFFFFFF; }
  return h;
}
Color _avatarColor(String email) => _avatarPalette[_hashEmail(email) % _avatarPalette.length];
IconData _avatarIcon(String email) => _avatarIcons[_hashEmail(email) % _avatarIcons.length];

class ProgresoScreen extends StatefulWidget {
  const ProgresoScreen({super.key});
  @override
  ProgresoScreenState createState() => ProgresoScreenState();
}

class ProgresoScreenState extends State<ProgresoScreen> with WidgetsBindingObserver {
  Estadisticas? _estadisticas;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    cargarEstadisticas();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Refresca estadísticas cuando la app vuelve a primer plano
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      cargarEstadisticas();
    }
  }

  Future<void> cargarEstadisticas() async {
    setState(() => _isLoading = true);
    try {
      final token = await AuthService.getToken();
      final user  = await AuthService.getCurrentUser();
      if (token == null || user == null) throw Exception('No autenticado');
      final estadisticas = await ApiService.getEstadisticas(user.id);
      if (!mounted) return;
      setState(() { _estadisticas = estadisticas; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppToast.show(context, 'Error al cargar estadísticas: $e', type: ToastType.error);
    }
  }

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[200]!,
        highlightColor: Colors.grey[50]!,
        child: Column(children: [
          Container(height: 130, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Container(height: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
            const SizedBox(width: 12),
            Expanded(child: Container(height: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Container(height: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
            const SizedBox(width: 12),
            Expanded(child: Container(height: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
          ]),
          const SizedBox(height: 16),
          Container(height: 200, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _naranja,
      onRefresh: cargarEstadisticas,
      child: _isLoading
          ? _buildSkeleton()
          : _estadisticas == null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline_rounded, size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('Error cargando estadísticas', style: TextStyle(color: Colors.grey)),
                ]))
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    // â”€â”€ 1. Header usuario â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                    FutureBuilder(
                      future: AuthService.getCurrentUser(),
                      builder: (_, snap) {
                        if (!snap.hasData) return const SizedBox();
                        return _UserHeader(usuario: snap.data!);
                      },
                    ),
                    const SizedBox(height: 20),

                    // â”€â”€ 2. Gráfica evolución (justo debajo del header) â”€
                    if (_estadisticas!.evolucion30d.isNotEmpty) ...[
                      _SectionTitle(icon: Icons.trending_up_rounded, text: 'Evolución (30 días)'),
                      const SizedBox(height: 12),
                      Container(
                        height: 190,
                        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0,2))],
                        ),
                        child: _GraficaEvolucion(evolucion: _estadisticas!.evolucion30d),
                      ),
                      const SizedBox(height: 20),
                    ] else if (_estadisticas!.historial.isNotEmpty) ...[
                      _SectionTitle(icon: Icons.trending_up_rounded, text: 'Evolución de Notas'),
                      const SizedBox(height: 12),
                      Container(
                        height: 190,
                        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0,2))],
                        ),
                        child: _GraficaNotas(historial: _estadisticas!.historial),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // â”€â”€ 3. KPI grid â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                    Row(children: [
                      Expanded(child: _KpiCard(
                        icon: Icons.assignment_turned_in_rounded,
                        color: _naranja,
                        label: 'Tests',
                        value: _estadisticas!.testsCompletados.toString(),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _KpiCard(
                        icon: Icons.check_circle_rounded,
                        color: const Color(0xFF2E7D32),
                        label: 'Correctas',
                        value: _estadisticas!.preguntasCorrectas.toString(),
                      )),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _PorcentajeCard(
                        porcentaje: _estadisticas!.porcentajeAciertos)),
                      const SizedBox(width: 12),
                      Expanded(child: _KpiCard(
                        icon: Icons.local_fire_department_rounded,
                        color: const Color(0xFFB00020),
                        label: 'Racha',
                        value: '${_estadisticas!.diasConsecutivos}d',
                      )),
                    ]),

                    // â”€â”€ 4. Resumen por oposición (temas + historial) â”€â”€â”€
                    if (_estadisticas!.temasDebiles.isNotEmpty ||
                        _estadisticas!.historial.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _SectionTitle(icon: Icons.school_rounded, text: 'Por tipo de oposición'),
                      const SizedBox(height: 12),
                      _OposicionDashboard(
                        temasDebiles: _estadisticas!.temasDebiles,
                        historial: _estadisticas!.historial,
                      ),
                    ],
                  ]),
                ),
    );
  }
}

// â”€â”€ Widgets de Progreso â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SectionTitle extends StatelessWidget {
  final IconData icon; final String text;
  const _SectionTitle({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 20, color: _naranja),
      const SizedBox(width: 8),
      Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87)),
    ]);
  }
}

class _UserHeader extends StatelessWidget {
  final dynamic usuario;
  const _UserHeader({required this.usuario});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_naranja, _naranjaOsc],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _naranja.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        Container(
          width: 66, height: 66,
          decoration: BoxDecoration(
            color: _avatarColor(usuario.email),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [BoxShadow(
              color: _avatarColor(usuario.email).withOpacity(0.5),
              blurRadius: 10, offset: const Offset(0, 3),
            )],
          ),
          child: Center(
            child: Icon(_avatarIcon(usuario.email), size: 32, color: Colors.white),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(usuario.nombre,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 2),
          Text(usuario.email,
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8))),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.school_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 4),
              Text(usuario.isPremium ? 'PREMIUM' : 'Gratuito',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13)),
            ]),
          ),
        ])),
      ]),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon; final Color color; final String label; final String value;
  const _KpiCard({required this.icon, required this.color, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0,2))],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]),
    );
  }
}

class _PorcentajeCard extends StatelessWidget {
  final double porcentaje;
  const _PorcentajeCard({required this.porcentaje});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0,2))],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircularPercentIndicator(
          radius: 38,
          lineWidth: 7,
          percent: (porcentaje / 100).clamp(0.0, 1.0),
          center: Text('${porcentaje.toStringAsFixed(0)}%',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.black87)),
          progressColor: _naranja,
          backgroundColor: const Color(0xFFFFCC80),
          circularStrokeCap: CircularStrokeCap.round,
        ),
        const SizedBox(height: 8),
        Text('% Aciertos', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]),
    );
  }
}

class _GraficaNotas extends StatelessWidget {
  final List<HistorialTest> historial;
  const _GraficaNotas({required this.historial});
  @override
  Widget build(BuildContext context) {
    final datos = historial.take(7).toList().reversed.toList();
    if (datos.isEmpty) return const SizedBox();
    final spots = datos.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.nota)).toList();
    return LineChart(LineChartData(
      gridData: FlGridData(
        show: true, drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: Colors.grey.shade100, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (v, _) => Text('T${v.toInt() + 1}',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
        )),
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 28,
          getTitlesWidget: (v, _) => Text('${v.toInt()}',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
        )),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      minY: 0, maxY: 10,
      lineBarsData: [LineChartBarData(
        spots: spots, isCurved: true,
        color: _naranja, barWidth: 3,
        dotData: FlDotData(
          getDotPainter: (_, __, ___, ____) =>
              FlDotCirclePainter(radius: 5, color: _naranja, strokeWidth: 2, strokeColor: Colors.white),
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: [_naranja.withOpacity(0.25), _naranja.withOpacity(0.0)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
      )],
    ));
  }
}

class _HistorialCard extends StatelessWidget {
  final HistorialTest test;
  const _HistorialCard({required this.test});
  Color _color(double nota) {
    if (nota >= 8) return const Color(0xFF2E7D32);
    if (nota >= 6) return const Color(0xFFE65100);
    return const Color(0xFFB00020);
  }
  @override
  Widget build(BuildContext context) {
    final c = _color(test.nota);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(test.nota.toStringAsFixed(1),
              style: TextStyle(fontWeight: FontWeight.w800, color: c, fontSize: 15))),
        ),
        title: Text(test.tema,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text('${test.fecha.day}/${test.fecha.month}/${test.fecha.year}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade300),
        onTap: () => HapticFeedback.selectionClick(),
      ),
    );
  }
}


// â”€â”€ Dashboard por oposición: temas débiles + historial fusionados â”€â”€â”€â”€â”€â”€â”€â”€â”€
//
// Agrupa ambas listas por tipo de oposición en una sola sección.
// Cada bloque muestra los temas a reforzar y los últimos tests de esa oposición.
class _OposicionDashboard extends StatelessWidget {
  final List<TemaDebil> temasDebiles;
  final List<HistorialTest> historial;
  const _OposicionDashboard({required this.temasDebiles, required this.historial});

  /// Recoge todos los tipos de oposición presentes en ambas listas,
  /// respetando el orden de aparición.
  List<String> _oposiciones() {
    final seen = <String>{};
    final result = <String>[];
    for (final t in temasDebiles) {
      final k = t.oposicion.isNotEmpty ? t.oposicion : 'Sin categoría';
      if (seen.add(k)) result.add(k);
    }
    for (final h in historial) {
      final k = h.oposicion.isNotEmpty ? h.oposicion : 'Sin categoría';
      if (seen.add(k)) result.add(k);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final oposiciones = _oposiciones();
    int globalIndex = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: oposiciones.map((oposicion) {
        final temas = temasDebiles
            .where((t) => (t.oposicion.isNotEmpty ? t.oposicion : 'Sin categoría') == oposicion)
            .toList();
        final tests = historial
            .where((h) => (h.oposicion.isNotEmpty ? h.oposicion : 'Sin categoría') == oposicion)
            .take(5)
            .toList();

        final widget = _OposicionBloque(
          oposicion:   oposicion,
          temas:       temas,
          tests:       tests,
          startIndex:  globalIndex,
        );
        globalIndex += temas.length;
        return widget;
      }).toList(),
    );
  }
}

// â”€â”€ Bloque individual por oposición â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _OposicionBloque extends StatefulWidget {
  final String oposicion;
  final List<TemaDebil> temas;
  final List<HistorialTest> tests;
  final int startIndex;
  const _OposicionBloque({
    required this.oposicion, required this.temas,
    required this.tests, required this.startIndex,
  });
  @override
  State<_OposicionBloque> createState() => _OposicionBloqueState();
}

class _OposicionBloqueState extends State<_OposicionBloque> {
  bool _historialExpanded = true; // expandido por defecto

  Color _colorBarra(double pct) {
    if (pct <= 20) return const Color(0xFFB00020);
    if (pct <= 40) return const Color(0xFFC62828);
    if (pct <= 60) return const Color(0xFFE65100);
    if (pct <= 80) return const Color(0xFF1565C0);
    return const Color(0xFF2E7D32);
  }

  Color _colorNota(double nota) {
    if (nota >= 8) return const Color(0xFF2E7D32);
    if (nota >= 6) return const Color(0xFFE65100);
    return const Color(0xFFB00020);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // â”€â”€ Cabecera pill oposición â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _naranja.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _naranja.withOpacity(0.25), width: 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.school_rounded, size: 13, color: _naranja),
              const SizedBox(width: 5),
              Text(widget.oposicion,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800, color: _naranja)),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: Colors.grey.shade200, height: 1)),
        ]),
        const SizedBox(height: 10),

        // â”€â”€ Card principal â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2),
            )],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [


            // ── Temas a reforzar ──────────────────────────────────────
            if (widget.temas.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade700),
                  const SizedBox(width: 5),
                  Text('Temas a reforzar',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                          color: Colors.orange.shade700)),
                ]),
              ),
              ...widget.temas.asMap().entries.map((entry) {
                final localIdx = entry.key;
                final t = entry.value;
                final i = widget.startIndex + localIdx;
                final pct     = t.porcentajeAciertos;
                final color   = _colorBarra(pct);
                final pctNorm = (pct / 100).clamp(0.0, 1.0);

                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (localIdx > 0) Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey.shade100),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Fila: número + tema + porcentaje
                      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        Container(
                          width: 26, height: 26,
                          decoration: BoxDecoration(color: color.withOpacity(0.10), shape: BoxShape.circle),
                          child: Center(child: Text('${i + 1}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(t.tema,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87))),
                        Text('${pct.toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
                      ]),
                      const SizedBox(height: 8),
                      // Barra de progreso
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: pctNorm, minHeight: 6,
                          backgroundColor: color.withOpacity(0.10),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Datos: correctas / total
                      Text('${t.aciertos} de ${t.preguntasIntentadas} preguntas correctas',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ]),
                  ),
                ]);
              }),
            ],

            // ── Separador ────────────────────────────────────────────
            if (widget.temas.isNotEmpty && widget.tests.isNotEmpty)
              Divider(height: 1, color: Colors.grey.shade100),

            // ── Historial de tests (expandido por defecto) ────────────
            if (widget.tests.isNotEmpty) ...[
              InkWell(
                onTap: () => setState(() => _historialExpanded = !_historialExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    Icon(Icons.history_rounded, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 5),
                    Text('Últimos tests (${widget.tests.length})',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600)),
                    const Spacer(),
                    // Nota media de la oposición
                    if (widget.tests.isNotEmpty) ...[
                      Text('Media: ',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                      Text(
                        (widget.tests.map((h) => h.nota).reduce((a, b) => a + b) / widget.tests.length)
                            .toStringAsFixed(1),
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800,
                            color: _colorNota(widget.tests.map((h) => h.nota).reduce((a, b) => a + b) / widget.tests.length)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Icon(
                      _historialExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18, color: Colors.grey.shade400,
                    ),
                  ]),
                ),
              ),
              if (_historialExpanded)
                ...widget.tests.map((h) {
                  final c = _colorNota(h.nota);
                  return Column(children: [
                    Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey.shade100),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(children: [
                        // Badge nota
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                              color: c.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
                          child: Center(child: Text(h.nota.toStringAsFixed(1),
                              style: TextStyle(fontWeight: FontWeight.w800, color: c, fontSize: 15))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(h.tema, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                          const SizedBox(height: 2),
                          Text('${h.fecha.day}/${h.fecha.month}/${h.fecha.year}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                        ])),
                        // Indicador semáforo compacto
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                        ),
                      ]),
                    ),
                  ]);
                }),
            ],

          ]),
        ),
      ]),
    );
  }
}


// â”€â”€ Gráfica evolución 30 días (vista BD evolucion_usuario_30dias) â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _GraficaEvolucion extends StatelessWidget {
  final List<EvolucionDia> evolucion;
  const _GraficaEvolucion({required this.evolucion});

  @override
  Widget build(BuildContext context) {
    if (evolucion.isEmpty) return const SizedBox();
    final spots = evolucion.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), e.value.porcentajePromedio / 10)).toList();

    return LineChart(LineChartData(
      gridData: FlGridData(
        show: true, drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          interval: evolucion.length > 7 ? (evolucion.length / 5).ceilToDouble() : 1,
          getTitlesWidget: (v, _) {
            final idx = v.toInt();
            if (idx < 0 || idx >= evolucion.length) return const SizedBox();
            final fecha = evolucion[idx].fecha;
            final parts = fecha.split('-');
            return Text('${parts[2]}/${parts[1]}',
                style: TextStyle(fontSize: 9, color: Colors.grey.shade400));
          },
        )),
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 28,
          getTitlesWidget: (v, _) => Text('${v.toInt()}',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
        )),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      minY: 0, maxY: 10,
      lineBarsData: [LineChartBarData(
        spots: spots, isCurved: true,
        color: _naranja, barWidth: 3,
        dotData: FlDotData(
          getDotPainter: (_, __, ___, ____) =>
              FlDotCirclePainter(radius: 5, color: _naranja, strokeWidth: 2, strokeColor: Colors.white),
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: [_naranja.withOpacity(0.25), _naranja.withOpacity(0.0)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
      )],
    ));
  }
}
