import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';

// ── Banner LifeOS animado — RF-21, RF-22, RF-23 ──────────────────────────
// - Widget puro Flutter (sin imagen), rendimiento máximo
// - Solo visible para usuarios FREE
// - Persistente, sin botón de cierre
// - Animaciones: shimmer sweep + partículas + glow pulsante

const _urlDestino = 'https://www.patreon.com/cw/Vagabond_/membership';

class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});
  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  bool _visible    = false;
  bool _comprobado = false;

  @override
  void initState() {
    super.initState();
    _comprobarRol();
  }

  Future<void> _comprobarRol() async {
    final isPremium = await AuthService.isPremium();
    final isAdmin   = await AuthService.isAdmin();
    if (!mounted) return;
    setState(() {
      _visible    = !isPremium && !isAdmin;
      _comprobado = true;
    });
  }

  Future<void> _onTap() async {
    HapticFeedback.selectionClick();
    final uri = Uri.parse(_urlDestino);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_comprobado || !_visible) return const SizedBox.shrink();
    return _AnimatedBanner(onTap: _onTap);
  }
}

// ── Widget animado principal ──────────────────────────────────────────────
class _AnimatedBanner extends StatefulWidget {
  final VoidCallback onTap;
  const _AnimatedBanner({required this.onTap});
  @override
  State<_AnimatedBanner> createState() => _AnimatedBannerState();
}

class _AnimatedBannerState extends State<_AnimatedBanner>
    with TickerProviderStateMixin {

  // Shimmer sweep de izquierda a derecha cada 3s
  late final AnimationController _shimmerCtrl;
  late final Animation<double>    _shimmerAnim;

  // Glow pulsante en el icono
  late final AnimationController _glowCtrl;
  late final Animation<double>    _glowAnim;

  // Partículas flotantes
  late final AnimationController _particleCtrl;
  late final Animation<double>    _particleAnim;

  @override
  void initState() {
    super.initState();

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(period: const Duration(milliseconds: 3500));
    _shimmerAnim = Tween<double>(begin: -0.3, end: 1.3)
        .animate(CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    _particleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_particleCtrl);
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _glowCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withOpacity(0.18),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(children: [
            // 1. Fondo degradado oscuro LifeOS
            _buildBackground(),
            // 2. Partículas flotantes
            AnimatedBuilder(
              animation: _particleAnim,
              builder: (_, __) => CustomPaint(
                size: const Size(double.infinity, 72),
                painter: _ParticlePainter(_particleAnim.value),
              ),
            ),
            // 3. Contenido principal
            _buildContent(),
            // 4. Shimmer sweep
            AnimatedBuilder(
              animation: _shimmerAnim,
              builder: (_, __) => CustomPaint(
                size: const Size(double.infinity, 72),
                painter: _ShimmerPainter(_shimmerAnim.value),
              ),
            ),
            // 5. Etiqueta PUBLICIDAD (RGPD)
            _buildPublicidadLabel(),
          ]),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF060614), Color(0xFF0A0A22), Color(0xFF0D1030)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.only(left: 22, right: 12),
      child: Row(
        children: [
          // ── Logo / icono animado ────────────────────────────────────
          AnimatedBuilder(
            animation: _glowAnim,
            builder: (_, __) => Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00E5FF).withOpacity(0.12),
                boxShadow: [BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.35 * _glowAnim.value),
                  blurRadius: 16,
                  spreadRadius: 2,
                )],
                border: Border.all(
                  color: const Color(0xFF00E5FF).withOpacity(0.5 * _glowAnim.value),
                  width: 1.5,
                ),
              ),
              child: const Center(
                child: Icon(Icons.dns_rounded, color: Color(0xFF00E5FF), size: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // ── Texto principal ─────────────────────────────────────────
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(text: const TextSpan(children: [
                  TextSpan(text: 'Life', style: TextStyle(
                    color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.w800, letterSpacing: -0.5,
                  )),
                  TextSpan(text: 'OS ', style: TextStyle(
                    color: Color(0xFF00E5FF), fontSize: 18,
                    fontWeight: FontWeight.w800, letterSpacing: -0.5,
                  )),
                  TextSpan(text: 'Core', style: TextStyle(
                    color: Color(0xFFAA66FF), fontSize: 13,
                    fontWeight: FontWeight.w600,
                  )),
                ])),
                const SizedBox(height: 2),
                const Text('Host Your Own Ecosystem · Privacy First',
                    style: TextStyle(
                      color: Color(0xFF8899BB), fontSize: 10,
                      fontWeight: FontWeight.w500,
                    )),
              ],
            ),
          ),
          // ── Pills de features ───────────────────────────────────────
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _FeaturePill(icon: Icons.sync_rounded,    label: 'Self-Hosted'),
              const SizedBox(height: 4),
              _FeaturePill(icon: Icons.lock_rounded,    label: 'RGPD Ready'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPublicidadLabel() {
    return Positioned(
      left: 0, top: 0, bottom: 0,
      child: Container(
        width: 16,
        color: Colors.black.withOpacity(0.35),
        child: const RotatedBox(
          quarterTurns: 3,
          child: Text('PUBLICIDAD',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 5, fontWeight: FontWeight.w600,
                  color: Colors.white54, letterSpacing: 0.5)),
        ),
      ),
    );
  }
}

// ── Pill de feature ───────────────────────────────────────────────────────
class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF00E5FF).withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.25), width: 0.8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: const Color(0xFF00E5FF)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(
          color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.w600,
        )),
      ]),
    );
  }
}

// ── Painter: shimmer sweep ────────────────────────────────────────────────
class _ShimmerPainter extends CustomPainter {
  final double progress; // -0.3 → 1.3
  _ShimmerPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0 || progress > 1) return;
    final cx = size.width * progress;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          Colors.white.withOpacity(0.07),
          Colors.white.withOpacity(0.13),
          Colors.white.withOpacity(0.07),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(cx - 80, 0, 160, size.height));
    canvas.drawRect(Rect.fromLTWH(cx - 80, 0, 160, size.height), paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.progress != progress;
}

// ── Painter: partículas flotantes ─────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final double t; // 0.0 → 1.0 ciclico
  _ParticlePainter(this.t);

  static const _particles = [
    (0.25, 0.3, 2.5),  // (x relativo, fase, radio)
    (0.55, 0.6, 1.8),
    (0.78, 0.1, 2.0),
    (0.42, 0.8, 1.5),
    (0.88, 0.45, 2.2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF00E5FF).withOpacity(0.35);
    for (final (xRel, fase, r) in _particles) {
      final phase = (t + fase) % 1.0;
      // flotación: empieza abajo, sube y desaparece
      final y = size.height * (1.0 - phase);
      final opacity = phase < 0.2
          ? phase / 0.2
          : phase > 0.8
              ? (1.0 - phase) / 0.2
              : 1.0;
      paint.color = const Color(0xFF00E5FF).withOpacity(0.30 * opacity);
      canvas.drawCircle(Offset(size.width * xRel, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}
