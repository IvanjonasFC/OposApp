import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
import '../cache/hive_cache.dart';
import '../models/convocatoria.dart';
import '../services/api_service.dart';
import '../widgets/app_toast.dart';

const _naranja    = Color(0xFFFF6B00);
const _naranjaOsc = Color(0xFFE55A00);
const _fondo      = Color(0xFFF5F5F5);

class BOPAScreen extends StatefulWidget {
  @override
  _BOPAScreenState createState() => _BOPAScreenState();
}

class _BOPAScreenState extends State<BOPAScreen>
    with SingleTickerProviderStateMixin {
  List<Convocatoria> _convocatorias = [];
  List<Convocatoria> _favoritos = [];
  bool _isLoading = true;
  bool _isMoreLoading = false;
  String _errorMessage = '';
  bool _favoritosOffline = false;   // true cuando los favoritos vienen de caché local
  final _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 0;
  bool _hasMore = true;
  Timer? _debounce;
  bool _modoFavoritos = false;
  late TabController _tabController;

  // ── Filtros ──────────────────────────────────────────────
  int? _filtroAnio;
  String? _filtroCategoria;
  bool get _hayFiltrosActivos => _filtroAnio != null || _filtroCategoria != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      HapticFeedback.selectionClick();
      setState(() => _modoFavoritos = _tabController.index == 1);
      if (_tabController.index == 1) _cargarFavoritos();
    });
    _cargarConvocatorias(refresh: true);
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading && !_isMoreLoading && _hasMore &&
          !_modoFavoritos && _searchController.text.isEmpty) {
        _cargarConvocatorias();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final query = _searchController.text.trim();
      if (query.isEmpty) _cargarConvocatorias(refresh: true);
      else _buscarFullText(query);
    });
  }

  Future<void> _cargarConvocatorias({bool refresh = false}) async {
    if (refresh) {
      setState(() { _isLoading = true; _errorMessage = ''; _currentPage = 0; _hasMore = true; });
    } else {
      setState(() => _isMoreLoading = true);
    }
    try {
      final nuevas = await ApiService.getConvocatorias(_currentPage, 20);
      if (!mounted) return;
      if (refresh && nuevas.isNotEmpty) HiveCache.saveConvocatorias(nuevas);
      setState(() {
        if (refresh) _convocatorias = nuevas;
        else _convocatorias.addAll(nuevas);
        if (nuevas.length < 20) _hasMore = false;
        else _currentPage++;
        _isLoading = false;
        _isMoreLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (refresh && HiveCache.hasConvocatorias()) {
        final cached = HiveCache.getCachedConvocatorias();
        setState(() {
          _convocatorias = cached;
          _hasMore = false;
          _isLoading = false;
          _isMoreLoading = false;
          _errorMessage = 'Sin conexión — mostrando ${cached.length} convocatorias guardadas';
        });
      } else {
        setState(() { _errorMessage = e.toString(); _isLoading = false; _isMoreLoading = false; });
      }
    }
  }

  Future<void> _buscarFullText(String termino) async {
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      final resultados = await ApiService.buscarConvocatorias(termino);
      if (!mounted) return;
      setState(() { _convocatorias = resultados; _hasMore = false; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _errorMessage = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _cargarFavoritos() async {
    setState(() { _isLoading = true; _favoritosOffline = false; });
    try {
      final favs = await ApiService.getFavoritos();
      if (!mounted) return;
      // Persistir en caché para acceso offline (RF-08)
      await HiveCache.saveFavoritos(favs);
      setState(() { _favoritos = favs; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      // Sin red → intentar caché local antes de mostrar error
      if (HiveCache.hasFavoritos()) {
        final cached = HiveCache.getCachedFavoritos();
        setState(() {
          _favoritos = cached;
          _isLoading = false;
          _favoritosOffline = true;
        });
      } else {
        setState(() { _errorMessage = e.toString(); _isLoading = false; });
      }
    }
  }

  Future<void> _toggleFavorito(Convocatoria conv) async {
    HapticFeedback.lightImpact();
    try {
      if (conv.guardada) {
        await ApiService.eliminarFavorito(conv.id);
        // Quitar del caché local también
        await HiveCache.actualizarFavorito(conv.id, false);
      } else {
        await ApiService.guardarFavorito(conv.id);
      }
      setState(() {
        _convocatorias = _convocatorias.map((c) =>
            c.id == conv.id ? c.copyWith(guardada: !c.guardada) : c).toList();
        _favoritos = _favoritos.map((c) =>
            c.id == conv.id ? c.copyWith(guardada: !c.guardada) : c).toList();
        // Si se está eliminando un favorito, quitarlo de la lista de guardadas
        if (conv.guardada && _modoFavoritos) {
          _favoritos.removeWhere((c) => c.id == conv.id);
        }
      });
      // Refrescar caché con la lista actualizada
      await HiveCache.saveFavoritos(_favoritos);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, 'Error al guardar favorito: $e', type: ToastType.error);
    }
  }

  /// Aplica filtros activos sobre una lista de convocatorias
  List<Convocatoria> _aplicarFiltros(List<Convocatoria> lista) {
    var result = lista;
    if (_filtroAnio != null) {
      result = result.where((c) => c.fechaPublicacion.year == _filtroAnio).toList();
    }
    if (_filtroCategoria != null) {
      result = result.where((c) =>
        c.categoria != null && c.categoria!.toLowerCase() == _filtroCategoria!.toLowerCase()
      ).toList();
    }
    return result;
  }

  /// Extrae los años y categorías disponibles para los filtros
  Set<int> get _aniosDisponibles {
    final src = _modoFavoritos ? _favoritos : _convocatorias;
    return src.map((c) => c.fechaPublicacion.year).toSet();
  }

  Set<String> get _categoriasDisponibles {
    final src = _modoFavoritos ? _favoritos : _convocatorias;
    return src.where((c) => c.categoria != null && c.categoria!.isNotEmpty)
        .map((c) => c.categoria!).toSet();
  }

  void _mostrarFiltros() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          final anios = _aniosDisponibles.toList()..sort((a, b) => b.compareTo(a));
          final categorias = _categoriasDisponibles.toList()..sort();
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Handle
              Container(width: 40, height: 4, decoration: BoxDecoration(
                color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              // Título
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.filter_list_rounded, color: _naranja),
                ),
                const SizedBox(width: 12),
                const Text('Filtrar convocatorias',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                if (_hayFiltrosActivos)
                  TextButton(
                    onPressed: () {
                      setSheetState(() {});
                      setState(() { _filtroAnio = null; _filtroCategoria = null; });
                      Navigator.pop(context);
                    },
                    child: const Text('Limpiar', style: TextStyle(color: _naranja, fontWeight: FontWeight.w600)),
                  ),
              ]),
              const SizedBox(height: 20),
              // ── Filtro por año ──
              if (anios.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Año de publicación',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black54)),
                ),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: anios.map((anio) {
                  final seleccionado = _filtroAnio == anio;
                  return ChoiceChip(
                    label: Text('$anio'),
                    selected: seleccionado,
                    onSelected: (sel) {
                      setState(() => _filtroAnio = sel ? anio : null);
                      setSheetState(() {});
                    },
                    selectedColor: _naranja,
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: TextStyle(
                      color: seleccionado ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: BorderSide.none,
                  );
                }).toList()),
                const SizedBox(height: 20),
              ],
              // ── Filtro por categoría ──
              if (categorias.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Categoría',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black54)),
                ),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: categorias.map((cat) {
                  final seleccionado = _filtroCategoria == cat;
                  return ChoiceChip(
                    label: Text(cat, style: const TextStyle(fontSize: 12)),
                    selected: seleccionado,
                    onSelected: (sel) {
                      setState(() => _filtroCategoria = sel ? cat : null);
                      setSheetState(() {});
                    },
                    selectedColor: _naranja,
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: TextStyle(
                      color: seleccionado ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: BorderSide.none,
                  );
                }).toList()),
                const SizedBox(height: 20),
              ],
              // Botón aplicar
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _naranja,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _hayFiltrosActivos ? 'Ver resultados filtrados' : 'Cerrar',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  /// Abre el bottom sheet con la información completa de la convocatoria
  void _abrirDetalle(Convocatoria conv) {
    HapticFeedback.lightImpact();
    setState(() {
      _convocatorias = _convocatorias.map((c) =>
          c.id == conv.id ? c.copyWith(leida: true) : c).toList();
      _favoritos = _favoritos.map((c) =>
          c.id == conv.id ? c.copyWith(leida: true) : c).toList();
    });
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConvocatoriaDetalleSheet(convocatoria: conv),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 6,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[200]!,
        highlightColor: Colors.grey[50]!,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          height: 88,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listaBase = _modoFavoritos ? _favoritos : _convocatorias;
    final lista = _aplicarFiltros(listaBase);
    return Column(
      children: [
        Container(
          color: _naranja,
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.article_rounded), text: 'Convocatorias'),
              Tab(icon: Icon(Icons.bookmark_rounded), text: 'Guardadas'),
            ],
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.black87),
                onTap: () => HapticFeedback.selectionClick(),
                decoration: InputDecoration(
                  hintText: _modoFavoritos ? 'Buscar en guardadas...' : 'Buscar convocatorias...',
                  hintStyle: const TextStyle(color: Colors.black38),
                  prefixIcon: const Icon(Icons.search_rounded, color: _naranja),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.black38),
                          onPressed: () { HapticFeedback.selectionClick(); _searchController.clear(); })
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Botón de filtros con badge
            Stack(children: [
              IconButton(
                onPressed: _mostrarFiltros,
                icon: Icon(
                  Icons.tune_rounded,
                  color: _hayFiltrosActivos ? _naranja : Colors.grey.shade500,
                ),
                tooltip: 'Filtros',
              ),
              if (_hayFiltrosActivos)
                Positioned(
                  right: 6, top: 6,
                  child: Container(
                    width: 10, height: 10,
                    decoration: const BoxDecoration(
                      color: _naranja, shape: BoxShape.circle,
                    ),
                  ),
                ),
            ]),
          ]),
        ),
        const Divider(height: 1),
        // ── Chips de filtros activos ──
        if (_hayFiltrosActivos)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            color: const Color(0xFFFFF3E0),
            child: Row(children: [
              const Icon(Icons.filter_list_rounded, size: 14, color: _naranja),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  [
                    if (_filtroAnio != null) 'Año: $_filtroAnio',
                    if (_filtroCategoria != null) _filtroCategoria!,
                  ].join(' · ') + ' — ${lista.length} resultado${lista.length != 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 12, color: _naranja, fontWeight: FontWeight.w600),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() { _filtroAnio = null; _filtroCategoria = null; }),
                child: const Icon(Icons.close_rounded, size: 16, color: _naranja),
              ),
            ]),
          ),
        Expanded(
          child: _isLoading
              ? _buildSkeletonList()
              : _errorMessage.isNotEmpty
                  ? _ErrorView(message: _errorMessage, onRetry: () => _cargarConvocatorias(refresh: true))
                  : lista.isEmpty
                      ? _EmptyView(isFavoritos: _modoFavoritos)
                      : RefreshIndicator(
                          color: _naranja,
                          onRefresh: () => _modoFavoritos
                              ? _cargarFavoritos()
                              : _cargarConvocatorias(refresh: true),
                          child: Column(children: [
                            // Banner offline — solo en pestaña Guardadas sin conexión
                            if (_modoFavoritos && _favoritosOffline)
                              _OfflineBanner(),
                            Expanded(
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                                itemCount: lista.length + (_isMoreLoading ? 1 : 0),
                                itemBuilder: (_, index) {
                                  if (index == lista.length) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      child: Center(child: CircularProgressIndicator(color: _naranja)),
                                    );
                                  }
                                  final conv = lista[index];
                                  return _ConvocatoriaCard(
                                    convocatoria: conv,
                                    onTap: () => _abrirDetalle(conv),
                                    onFavorito: () => _toggleFavorito(conv),
                                  );
                                },
                              ),
                            ),
                          ]),
                        ),
        ),
      ],
    );
  }
}

// ── Bottom Sheet de detalle completo ─────────────────────────────────────
class _ConvocatoriaDetalleSheet extends StatelessWidget {
  final Convocatoria convocatoria;
  const _ConvocatoriaDetalleSheet({required this.convocatoria});

  Future<void> _abrirEnNavegador(BuildContext context) async {
    final url = convocatoria.urlBopa;
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay enlace disponible para esta convocatoria')));
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se puede abrir el enlace')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final hayTexto = convocatoria.textoCompleto != null &&
        convocatoria.textoCompleto!.trim().isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Cabecera naranja
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B00), Color(0xFFE55A00)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.description_rounded, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      convocatoria.titulo,
                      style: const TextStyle(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Contenido scrollable
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                children: [
                  // Chips de metadatos
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      if (convocatoria.categoria != null && convocatoria.categoria!.isNotEmpty)
                        _Chip(icon: Icons.category_rounded, label: convocatoria.categoria!),
                      if (convocatoria.bopaNumero != null && convocatoria.bopaNumero!.isNotEmpty)
                        _Chip(icon: Icons.numbers_rounded, label: 'BOPA ${convocatoria.bopaNumero}'),
                      _Chip(icon: Icons.calendar_today_rounded,
                          label: dateFormat.format(convocatoria.fechaPublicacion)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Organismo
                  _InfoRow(
                    icon: Icons.account_balance_rounded,
                    label: 'Organismo',
                    valor: convocatoria.organismo,
                  ),
                  const SizedBox(height: 12),
                  // Enlace
                  if (convocatoria.urlBopa.isNotEmpty)
                    _InfoRow(
                      icon: Icons.link_rounded,
                      label: 'Enlace BOPA',
                      valor: convocatoria.urlBopa,
                      esEnlace: true,
                    ),
                  // Descripción / Texto completo
                  if (hayTexto) ...[
                    const SizedBox(height: 16),
                    const Text('Descripción',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                            color: Color(0xFFFF6B00))),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        convocatoria.textoCompleto!,
                        style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Botón Ver en BOPA
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _abrirEnNavegador(context),
                      icon: const Icon(Icons.open_in_browser_rounded),
                      label: const Text('Ver en el BOPA oficial',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chip de metadato ─────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B00).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: const Color(0xFFFF6B00)),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFFF6B00))),
      ]),
    );
  }
}

// ── Fila de información ───────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valor;
  final bool esEnlace;
  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.valor,
      this.esEnlace = false});
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(valor,
                style: TextStyle(
                  fontSize: 13,
                  color: esEnlace ? const Color(0xFFFF6B00) : Colors.black87,
                  fontWeight: FontWeight.w500,
                  decoration:
                      esEnlace ? TextDecoration.underline : TextDecoration.none,
                )),
          ]),
        ),
      ],
    );
  }
}

// ── Card de convocatoria ──────────────────────────────────────────────────
class _ConvocatoriaCard extends StatelessWidget {
  final Convocatoria convocatoria;
  final VoidCallback onTap;
  final VoidCallback onFavorito;
  const _ConvocatoriaCard(
      {required this.convocatoria,
      required this.onTap,
      required this.onFavorito});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final esNueva = !convocatoria.leida &&
        convocatoria.fechaScraping != null &&
        DateTime.now().difference(convocatoria.fechaScraping!).inDays <= 7;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: const Color(0xFFFF6B00).withOpacity(0.08),
          highlightColor: const Color(0xFFFF6B00).withOpacity(0.04),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: esNueva
                      ? const Color(0xFFFF6B00).withOpacity(0.12)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.description_rounded,
                    color: esNueva
                        ? const Color(0xFFFF6B00)
                        : Colors.grey.shade400,
                    size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(convocatoria.titulo,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: esNueva
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(convocatoria.organismo,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(
                            dateFormat.format(convocatoria.fechaPublicacion),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                        if (convocatoria.categoria != null &&
                            convocatoria.categoria!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(convocatoria.categoria!,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade400),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                        if (esNueva) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                                color: const Color(0xFFFF6B00),
                                borderRadius: BorderRadius.circular(8)),
                            child: const Text('NUEVA',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ]),
                    ]),
              ),
              IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    convocatoria.guardada
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    key: ValueKey(convocatoria.guardada),
                    color: convocatoria.guardada
                        ? const Color(0xFFFF6B00)
                        : Colors.grey.shade300,
                    size: 26,
                  ),
                ),
                onPressed: onFavorito,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Banner de aviso offline (favoritos desde caché) ───────────────────────
class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE65100).withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE65100).withOpacity(0.30)),
      ),
      child: Row(children: [
        const Icon(Icons.wifi_off_rounded, size: 16, color: Color(0xFFE65100)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Sin conexión — mostrando favoritos guardados localmente',
            style: TextStyle(
              fontSize: 12,
              color: const Color(0xFFE65100).withOpacity(0.90),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Vista de error ────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: const Color(0xFFB00020).withOpacity(0.1),
                shape: BoxShape.circle),
            child: const Icon(Icons.wifi_off_rounded,
                size: 48, color: Color(0xFFB00020)),
          ),
          const SizedBox(height: 16),
          const Text('Error de conexión',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87)),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B00),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Vista vacía ───────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  final bool isFavoritos;
  const _EmptyView({required this.isFavoritos});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: const Color(0xFFFF6B00).withOpacity(0.08),
              shape: BoxShape.circle),
          child: Icon(
              isFavoritos
                  ? Icons.bookmark_border_rounded
                  : Icons.inbox_rounded,
              size: 48,
              color: const Color(0xFFFF6B00).withOpacity(0.5)),
        ),
        const SizedBox(height: 16),
        Text(
            isFavoritos
                ? 'Sin convocatorias guardadas'
                : 'No hay convocatorias',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black54)),
      ]),
    );
  }
}
