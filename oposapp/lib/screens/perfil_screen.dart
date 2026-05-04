import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../widgets/app_toast.dart';

// ── Paleta ────────────────────────────────────────────────────────────────
const _naranja    = Color(0xFFFF6B00);
const _naranjaOsc = Color(0xFFE55A00);
const _fondo      = Color(0xFFF5F5F5);
const _rojo       = Color(0xFFB00020);

/// Colores del avatar — deterministas por email (sin overflow en web).
const _avatarPalette = [
  Color(0xFFFF6B00), Color(0xFF1565C0), Color(0xFF2E7D32),
  Color(0xFF6A1B9A), Color(0xFF00838F), Color(0xFFC62828),
  Color(0xFF4527A0), Color(0xFF00695C), Color(0xFFAD1457), Color(0xFFE65100),
];

/// Hash determinista del email para el color del avatar.
int _hash(String s) {
  int h = 5381;
  for (final c in s.codeUnits) h = ((h << 5) + h + c) & 0x7FFFFFFF;
  return h;
}

Color    _avatarColor(String e) => _avatarPalette[_hash(e) % _avatarPalette.length];

// ── Nombre visible — nunca mostrar email como nombre ─────────────────────
String _displayName(Usuario u) {
  final n = u.nombre.trim();
  // Si el nombre está vacío o coincide con el email completo → mostrar parte local
  if (n.isEmpty || n == u.email) {
    return u.email.split('@').first;
  }
  return n;
}

// ─────────────────────────────────────────────────────────────────────────
class PerfilScreen extends StatefulWidget {
  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  Key _futureKey = UniqueKey();

  void _reload() => setState(() => _futureKey = UniqueKey());

  // ── Acciones ─────────────────────────────────────────────────────────

  Future<void> _editarPerfil(BuildContext ctx, Usuario user) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => _EditarPerfilDialog(user: user),
    );
    if (ok == true) _reload();
  }

  Future<void> _cerrarSesion(BuildContext ctx) async {
    final ok = await _confirm(
      ctx,
      icon: Icons.logout_rounded, iconColor: _rojo,
      title: 'Cerrar sesión',
      body: '¿Quieres cerrar la sesión en este dispositivo?',
      accion: 'Cerrar sesión', accionColor: _rojo,
    );
    if (ok && ctx.mounted) {
      await AuthService.logout();
      if (ctx.mounted) ctx.go('/login');
    }
  }

  Future<void> _exportarDatos(BuildContext ctx) async {
    _showLoadingSnack(ctx, 'Exportando datos...');
    try {
      final datos = await ApiService.exportarDatos();
      final json = const JsonEncoder.withIndent('  ').convert(datos);
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
      await showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          title: Row(children: const [
            Icon(Icons.download_rounded, color: _naranja, size: 20),
            SizedBox(width: 8),
            Text('Exportación de datos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          content: SizedBox(
            width: double.maxFinite, height: 260,
            child: SingleChildScrollView(
              child: SelectableText(json,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.4)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: _naranja),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
      AppToast.show(ctx, 'No se pudieron exportar los datos', type: ToastType.error);
    }
  }

  Future<void> _politicaPrivacidad(BuildContext ctx) async {
    await showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        title: Row(children: const [
          Icon(Icons.shield_outlined, color: _naranja, size: 20),
          SizedBox(width: 8),
          Text('Política de privacidad',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: const SingleChildScrollView(
          child: _PrivacidadContent(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: _naranja),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _acercaDe(BuildContext ctx) async {
    await showDialog(
      context: ctx,
      builder: (_) => const _AcercaDeDialog(),
    );
  }

  Future<void> _solicitarBaja(BuildContext ctx) async {
    final ok = await _confirm(
      ctx,
      icon: Icons.delete_outline_rounded, iconColor: _rojo,
      title: 'Eliminar cuenta',
      body: 'Todos tus datos (tests, progreso y estadísticas) serán eliminados '
            'de forma permanente en un plazo de 48 horas.\n\n'
            'Esta acción no se puede deshacer.',
      accion: 'Eliminar mi cuenta', accionColor: _rojo,
    );
    if (!ok) return;
    try {
      await ApiService.solicitarBaja();
      if (!ctx.mounted) return;
      await AuthService.logout();
      if (!ctx.mounted) return;
      ctx.go('/login');
    } catch (e) {
      if (!ctx.mounted) return;
      AppToast.show(ctx, 'No se pudo procesar la solicitud', type: ToastType.error);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        title: const Text('Perfil'),
        backgroundColor: _naranja,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder<Usuario?>(
        key: _futureKey,
        future: AuthService.getCurrentUser(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: _naranja));
          }
          final user = snap.data!;
          return ListView(
            children: [
              _Header(user: user),
              const SizedBox(height: 20),
              _Section(title: 'Cuenta', items: [
                _Tile(
                  icon: Icons.person_outline_rounded,
                  label: 'Editar perfil',
                  onTap: () { HapticFeedback.selectionClick(); _editarPerfil(ctx, user); },
                ),
              ]),
              _Section(title: 'Privacidad y RGPD', items: [
                _Tile(
                  icon: Icons.download_outlined,
                  label: 'Exportar mis datos',
                  subtitle: 'Descarga tu información en formato JSON',
                  onTap: () { HapticFeedback.selectionClick(); _exportarDatos(ctx); },
                ),
                _Tile(
                  icon: Icons.shield_outlined,
                  label: 'Política de privacidad',
                  onTap: () { HapticFeedback.selectionClick(); _politicaPrivacidad(ctx); },
                ),
              ]),
              _Section(title: 'Acerca de', items: [
                _Tile(
                  icon: Icons.info_outline_rounded,
                  label: 'Acerca de OposApp',
                  onTap: () { HapticFeedback.selectionClick(); _acercaDe(ctx); },
                ),
              ]),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(children: [
                  _ActionButton(
                    icon: Icons.logout_rounded,
                    label: 'Cerrar sesión',
                    color: _rojo, filled: true,
                    onTap: () { HapticFeedback.mediumImpact(); _cerrarSesion(ctx); },
                  ),
                  const SizedBox(height: 10),
                  _ActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: 'Eliminar mi cuenta',
                    color: _rojo, filled: false,
                    onTap: () { HapticFeedback.heavyImpact(); _solicitarBaja(ctx); },
                  ),
                ]),
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  void _showLoadingSnack(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF323232),
      content: Row(children: [
        const SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        const SizedBox(width: 12),
        Text(msg, style: const TextStyle(color: Colors.white)),
      ]),
      duration: const Duration(seconds: 10),
    ));
  }

  Future<bool> _confirm(BuildContext ctx, {
    required IconData icon, required Color iconColor,
    required String title, required String body,
    required String accion, required Color accionColor,
  }) async {
    final r = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        title: Row(children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: Text(body,
            style: const TextStyle(fontSize: 14, height: 1.55, color: Color(0xFF424242))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_, false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF757575))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(_, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: accionColor, foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(accion, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
    return r == true;
  }
}

// ── Header ────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final Usuario user;
  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    final name = _displayName(user);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_naranja, _naranjaOsc],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(children: [
        // Avatar
        Container(
          width: 84, height: 84,
          decoration: BoxDecoration(
            color: _avatarColor(user.email),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: Center(
            child: Text(
              // Iniciales — máximo 2 chars
              name.trim().isEmpty ? '?' : (
                name.trim().split(' ').length >= 2
                  ? '${name.trim().split(' ')[0][0]}${name.trim().split(' ')[1][0]}'.toUpperCase()
                  : name.trim()[0].toUpperCase()
              ),
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Nombre
        Text(name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 3),
        // Email
        Text(user.email,
            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.80))),
        const SizedBox(height: 12),
        // Badges
        Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [
          _Badge(
            icon: user.emailVerificado ? Icons.verified_rounded : Icons.mark_email_unread_rounded,
            label: user.emailVerificado ? 'Email verificado' : 'Verificación pendiente',
            iconColor: user.emailVerificado ? Colors.greenAccent : Colors.amberAccent,
          ),
          _Badge(
            icon: user.isPremium ? Icons.workspace_premium_rounded : Icons.school_outlined,
            label: user.isPremium ? 'Premium' : 'Plan Gratuito',
            iconColor: Colors.white,
          ),
        ]),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon; final String label; final Color iconColor;
  const _Badge({required this.icon, required this.label, required this.iconColor});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: iconColor),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Sección + Tile ────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title; final List<Widget> items;
  const _Section({required this.title, required this.items});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title.toUpperCase(),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500, letterSpacing: 0.6)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
          ),
          child: Column(
            children: items.asMap().entries.map((e) => Column(children: [
              e.value,
              if (e.key < items.length - 1)
                Divider(height: 1, indent: 52, color: Colors.grey.shade100),
            ])).toList(),
          ),
        ),
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon; final String label;
  final String? subtitle; final VoidCallback onTap;
  const _Tile({required this.icon, required this.label, this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
            color: _naranja.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, color: _naranja, size: 19),
      ),
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500))
          : null,
      trailing: Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey.shade300),
      onTap: onTap,
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon; final String label;
  final Color color; final bool filled; final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label,
      required this.color, required this.filled, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, height: 50,
      child: filled
          ? ElevatedButton.icon(
              onPressed: onTap, icon: Icon(icon, size: 18),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: color, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ))
          : OutlinedButton.icon(
              onPressed: onTap, icon: Icon(icon, color: color, size: 18),
              label: Text(label, style: TextStyle(color: color)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: color.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              )),
    );
  }
}

// ── Diálogo editar perfil ─────────────────────────────────────────────────
class _EditarPerfilDialog extends StatefulWidget {
  final Usuario user;
  const _EditarPerfilDialog({required this.user});
  @override
  State<_EditarPerfilDialog> createState() => _EditarPerfilDialogState();
}

class _EditarPerfilDialogState extends State<_EditarPerfilDialog> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _apellidosCtrl;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Nombre real: si coincide con email completo, mostrar vacío para que el usuario lo rellene
    final nombreReal = widget.user.nombre.trim();
    final esEmailComoNombre = nombreReal == widget.user.email || nombreReal.isEmpty;
    _nombreCtrl    = TextEditingController(text: esEmailComoNombre ? '' : nombreReal);
    _apellidosCtrl = TextEditingController(text: widget.user.apellidos ?? '');
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidosCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre    = _nombreCtrl.text.trim();
    final apellidos = _apellidosCtrl.text.trim();

    if (nombre.isEmpty) {
      setState(() => _error = 'El nombre no puede estar vacío');
      return;
    }
    if (nombre.length < 2) {
      setState(() => _error = 'El nombre debe tener al menos 2 caracteres');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.updatePerfil(
        nombre:    nombre,
        apellidos: apellidos,
        username:  nombre,
      );
      // Actualizar SharedPreferences para que el header refresque inmediatamente
      await AuthService.updateNombreLocal(nombre: nombre, apellidos: apellidos);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() { _error = 'No se pudo guardar. Inténtalo de nuevo.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      title: Row(children: const [
        Icon(Icons.edit_outlined, color: _naranja, size: 20),
        SizedBox(width: 8),
        Text('Editar perfil',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ]),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 4),
          _Campo(
            ctrl: _nombreCtrl,
            label: 'Nombre',
            icon: Icons.person_outline_rounded,
            hint: 'Tu nombre',
            autofocus: true,
          ),
          const SizedBox(height: 12),
          _Campo(
            ctrl: _apellidosCtrl,
            label: 'Apellidos',
            icon: Icons.badge_outlined,
            hint: 'Tus apellidos (opcional)',
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3F3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFCDD2)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: _rojo, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!,
                    style: const TextStyle(color: _rojo, fontSize: 12))),
              ]),
            ),
          ],
        ]),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _loading ? null : () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Cancelar',
                  style: TextStyle(color: Color(0xFF757575), fontWeight: FontWeight.w500)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: _loading ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: _naranja, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Guardar',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
        ]),
      ],
    );
  }
}

class _Campo extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final bool autofocus;
  const _Campo({
    required this.ctrl, required this.label,
    required this.icon, required this.hint,
    this.autofocus = false,
  });
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      autofocus: autofocus,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: Icon(icon, color: _naranja, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8F8F8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _naranja, width: 1.5),
        ),
      ),
    );
  }
}

// ── Política de privacidad — sin emojis ───────────────────────────────────
class _PrivacidadContent extends StatelessWidget {
  const _PrivacidadContent();
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: const [
        SizedBox(height: 8),
        _PItem(
          icon: Icons.storage_outlined,
          text: 'OposApp recoge tu email, nombre y actividad de estudio '
                'con el único fin de personalizar tu experiencia de preparación.',
        ),
        SizedBox(height: 12),
        _PItem(
          icon: Icons.lock_outline_rounded,
          text: 'Tus datos se almacenan en servidores propios ubicados en España '
                'y nunca se comparten con terceros ni con servicios cloud externos.',
        ),
        SizedBox(height: 12),
        _PItem(
          icon: Icons.edit_outlined,
          text: 'Puedes ejercer tus derechos de acceso, rectificación, portabilidad '
                'y supresión en cualquier momento desde esta pantalla.',
        ),
        SizedBox(height: 12),
        _PItem(
          icon: Icons.psychology_outlined,
          text: 'La inteligencia artificial que genera tus tests procesa '
                'los datos localmente. Ninguna pregunta ni respuesta '
                'sale de los servidores propios de la aplicación.',
        ),
      ],
    );
  }
}

class _PItem extends StatelessWidget {
  final IconData icon; final String text;
  const _PItem({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 17, color: _naranja),
      const SizedBox(width: 10),
      Expanded(
        child: Text(text,
            style: const TextStyle(fontSize: 13, height: 1.55, color: Color(0xFF424242))),
      ),
    ]);
  }
}

// ── Acerca de — sin Flutter showAboutDialog ───────────────────────────────
class _AcercaDeDialog extends StatelessWidget {
  const _AcercaDeDialog();
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
      title: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: _naranja.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.school_rounded, color: _naranja, size: 26),
          ),
          const SizedBox(width: 14),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('OposApp', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text('Versión 1.0.0', style: TextStyle(fontSize: 13, color: Color(0xFF757575))),
          ]),
        ]),
      ),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Divider(color: Colors.grey.shade100),
        const SizedBox(height: 10),
        const _InfoRow(icon: Icons.memory_outlined,   label: 'IA',        value: 'Ollama · Qwen3 64k'),
        const _InfoRow(icon: Icons.storage_outlined,  label: 'Backend',   value: 'Spring Boot 3 · Java 21'),
        const _InfoRow(icon: Icons.dataset_outlined,  label: 'Base de datos', value: 'PostgreSQL 15'),
        const _InfoRow(icon: Icons.phone_android_rounded, label: 'App',   value: 'Flutter 3.24'),
        const _InfoRow(icon: Icons.dns_outlined,      label: 'Servidor',  value: 'NAS Synology DS920+'),
        const SizedBox(height: 14),
        Text('TFG · DAM 2025-2026',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
        const SizedBox(height: 4),
      ]),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _naranja, foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon; final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(icon, size: 16, color: const Color(0xFF9E9E9E)),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF616161))),
        const Spacer(),
        Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF212121))),
      ]),
    );
  }
}
