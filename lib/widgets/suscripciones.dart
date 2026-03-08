import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../pantallas/dialog_agregar_suscripcion.dart';
import '../modelos/suscripcion.dart';
import '../servicios/base_datos.dart';

class SuscripcionesScreen extends StatefulWidget {
  final List<Suscripcion> suscripciones;
  final VoidCallback onChanged;

  const SuscripcionesScreen({
    super.key,
    required this.suscripciones,
    required this.onChanged,
  });

  @override
  State<SuscripcionesScreen> createState() => _SuscripcionesScreenState();
}

class _SuscripcionesScreenState extends State<SuscripcionesScreen>
    with TickerProviderStateMixin {
  // Paleta SKULL (salmón)
  static const Color coral = Color(0xFFFF6464);
  static const Color coralSoft = Color(0xFFFFB2B2);

  final List<Map<String, dynamic>> _iconosDisponibles = const [
    {'icono': Icons.movie, 'label': "Películas"},
    {'icono': Icons.music_note, 'label': "Música"},
    {'icono': Icons.tv, 'label': "TV"},
    {'icono': Icons.book, 'label': "Libros"},
    {'icono': Icons.cloud, 'label': "Cloud"},
    {'icono': Icons.gamepad, 'label': "Juegos"},
    {'icono': Icons.sports_esports, 'label': "eSports"},
    {'icono': Icons.fitness_center, 'label': "Fitness"},
    {'icono': Icons.fastfood, 'label': "Comida"},
    {'icono': Icons.wifi, 'label': "Internet"},
    {'icono': Icons.subscriptions, 'label': "Otro"},
  ];

  late final AnimationController _fabPulse;
  late final AnimationController _listAnim;
  List<Suscripcion> _suscripciones = [];
  bool _cargando = true;
  String? _error;

  double get _totalMensual =>
      _suscripciones.fold(0.0, (sum, s) => sum + s.monto);

  @override
  void initState() {
    super.initState();
    _fabPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);

    _listAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _cargarSuscripciones();
  }

  @override
  void dispose() {
    _fabPulse.dispose();
    _listAnim.dispose();
    super.dispose();
  }

  Future<void> _cargarSuscripciones() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final database = await BaseDatos.db;
      await BaseDatos.asegurarTablas(database);

      final lista = await BaseDatos.obtenerSuscripciones();
      if (!mounted) return;
      setState(() {
        _suscripciones = lista;
        _cargando = false;
      });
      _listAnim.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar. Pulsa para reintentar.';
        _cargando = false;
      });
    }
  }

  void _mostrarDialogoAgregar() {
    HapticFeedback.lightImpact();
    showGeneralDialog(
      context: context,
      barrierLabel: "Agregar suscripción",
      barrierDismissible: true,
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, _, __) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Center(
            child: DialogAgregarSuscripcion(
              onGuardar: (nombre, monto, icono, diaPago) async {
                final nueva = Suscripcion(
                  nombre: nombre,
                  monto: monto.toDouble(),
                  icono: icono,
                  diaPago: diaPago,
                );
                await BaseDatos.insertarSuscripcion(nueva);
                await _cargarSuscripciones();
                if (!mounted) return;
                widget.onChanged();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Suscripción guardada',
                        style: GoogleFonts.poppins()),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(
        opacity: anim,
        child: Transform.scale(
          scale: 0.98 + (anim.value * 0.02),
          child: child,
        ),
      ),
    );
  }

  Future<void> _eliminarSuscripcion(int index) async {
    final sub = _suscripciones[index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.delete_forever, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Eliminar suscripción'),
          ],
        ),
        content: Text('¿Eliminar "${sub.nombre}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true && mounted) {
      await BaseDatos.eliminarSuscripcion(sub.nombre);
      await _cargarSuscripciones();
      if (!mounted) return;
      widget.onChanged();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Suscripción eliminada', style: GoogleFonts.poppins()),
          behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _mostrarSelectorIcono(int index) async {
    final seleccionado = await showModalBottomSheet<IconData>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 10),
                Text("Selecciona un ícono",
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: _iconosDisponibles.map((icon) {
                    return GestureDetector(
                      onTap: () =>
                          Navigator.pop(ctx, icon['icono'] as IconData),
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                  colors: [coralSoft, coral],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight),
                              boxShadow: [
                                BoxShadow(
                                    color: coral.withOpacity(0.22),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4))
                              ],
                            ),
                            child: Icon(icon['icono'] as IconData,
                                color: Colors.white, size: 28),
                          ),
                          const SizedBox(height: 6),
                          Text(icon['label'] as String,
                              style: GoogleFonts.poppins(fontSize: 12.5)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (seleccionado != null && mounted) {
      final sub = _suscripciones[index];
      final actualizado = sub.copyWith(icono: seleccionado);
      await BaseDatos.actualizarSuscripcion(sub.nombre, actualizado);
      await _cargarSuscripciones();
      if (!mounted) return;
      widget.onChanged();
    }
  }

  Future<void> _mostrarMenuSuscripcion(Suscripcion sub, int index) async {
    HapticFeedback.mediumImpact();
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text('Editar',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _editarSuscripcion(sub, index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: Colors.redAccent),
                title: Text('Eliminar',
                    style: GoogleFonts.poppins(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _eliminarSuscripcion(index);
                },
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editarSuscripcion(Suscripcion sub, int index) async {
    final nombreCtrl = TextEditingController(text: sub.nombre);
    final montoCtrl =
        TextEditingController(text: sub.monto.toStringAsFixed(2));
    int diaPagoTmp = sub.diaPago;
    IconData iconTmp = sub.icono;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 16),
          child: _EditorSuscripcion(
            nombreCtrl: nombreCtrl,
            montoCtrl: montoCtrl,
            coral: coral,
            coralSoft: coralSoft,
            iconoInicial: iconTmp,
            diaInicial: diaPagoTmp,
            onDiaChanged: (d) => diaPagoTmp = d,
            onIconChanged: (i) => iconTmp = i,
            onGuardar: () async {
              final nombre = nombreCtrl.text.trim();
              final monto = double.tryParse(
                  montoCtrl.text.replaceAll(',', '.'));
              if (nombre.isEmpty || monto == null || monto <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text('Revisa nombre/monto',
                        style: GoogleFonts.poppins())));
                return;
              }
              final nuevo = sub.copyWith(
                  nombre: nombre,
                  monto: monto,
                  diaPago: diaPagoTmp,
                  icono: iconTmp);
              await BaseDatos.actualizarSuscripcion(sub.nombre, nuevo);
              await _cargarSuscripciones();
              if (!mounted) return;
              widget.onChanged();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Suscripción actualizada',
                      style: GoogleFonts.poppins()),
                  behavior: SnackBarBehavior.floating));
            },
          ),
        );
      },
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(76),
        child: AppBar(
          backgroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          title: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Suscripciones',
                style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .6,
                    color: Colors.black)),
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _cargarSuscripciones,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
                children: [
                  _HeaderTotal(
                    total: _totalMensual,
                    coral: coral,
                    coralSoft: coralSoft,
                    mostrandoTotal: !_cargando && _suscripciones.isNotEmpty,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      "Agrega tus suscripciones (Spotify, Netflix, etc.).\n"
                      "Tap: cambiar ícono  •  Mantén presionado: Editar / Eliminar",
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey[700]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_cargando)
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: _cargarSuscripciones,
                          icon: const Icon(Icons.refresh),
                          label: Text(_error!,
                              style: GoogleFonts.poppins()),
                        ),
                      ),
                    )
                  else if (_suscripciones.isEmpty)
                    _EmptyState(coral: coral, coralSoft: coralSoft)
                  else
                    AnimatedBuilder(
                      animation: _listAnim,
                      builder: (context, child) {
                        return Column(
                          children: List.generate(_suscripciones.length, (i) {
                            final sub = _suscripciones[i];
                            final animValue = CurvedAnimation(
                              parent: _listAnim,
                              curve: Interval(0.0,
                                  0.3 + (i / (_suscripciones.length * 1.5)),
                                  curve: Curves.easeOut),
                            ).value;
                            return Opacity(
                              opacity: animValue,
                              child: Transform.translate(
                                offset: Offset(0, (1 - animValue) * 16),
                                child: _ItemSuscripcion(
                                  sub: sub,
                                  coral: coral,
                                  coralSoft: coralSoft,
                                  onTap: () => _mostrarSelectorIcono(i),
                                  onLongPress: () =>
                                      _mostrarMenuSuscripcion(sub, i),
                                ),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                ],
              ),
            ),

            // FAB grande con halo animado
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: AnimatedBuilder(
                  animation: _fabPulse,
                  builder: (_, __) {
                    final t = _fabPulse.value;
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 36),
                        child: Container(
                          width: 140 + (t * 10),
                          height: 140 + (t * 10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: coral.withOpacity(0.06 * (0.5 + t / 2)),
                            boxShadow: [
                              BoxShadow(
                                color: coral.withOpacity(0.2 * (0.5 + t / 2)),
                                blurRadius: 24 + (t * 12),
                                spreadRadius: 4 + (t * 4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Botón interactivo (más grande)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                minimum: const EdgeInsets.only(bottom: 18),
                child: GestureDetector(
                  onTap: _mostrarDialogoAgregar,
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    _mostrarDialogoAgregar();
                  },
                  child: Hero(
                    tag: 'fab_suscripciones',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [coral, Color(0xFFFC5C7D)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: coral.withOpacity(0.35),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add, color: Colors.white, size: 30),
                          const SizedBox(width: 10),
                          Text(
                            'Agregar suscripción',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------- Widgets de apoyo ---------

class _ItemSuscripcion extends StatelessWidget {
  final Suscripcion sub;
  final Color coral;
  final Color coralSoft;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ItemSuscripcion({
    required this.sub,
    required this.coral,
    required this.coralSoft,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 6))
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Aro con gradiente
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [coralSoft, coral],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
              padding: const EdgeInsets.all(14),
              child: Icon(sub.icono, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sub.nombre,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 16.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.event, size: 14, color: Colors.grey[700]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          sub.diaPago == 31
                              ? 'Cobro: último día del mes'
                              : 'Cobro: día ${sub.diaPago}',
                          style: GoogleFonts.poppins(
                              fontSize: 12.5, color: Colors.grey[700]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: coral.withOpacity(.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: coral.withOpacity(.25)),
              ),
              child: Text(
                '\$${sub.monto.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                    fontSize: 14.5, fontWeight: FontWeight.w800, color: coral),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderTotal extends StatelessWidget {
  final double total;
  final bool mostrandoTotal;
  final Color coral;
  final Color coralSoft;

  const _HeaderTotal({
    required this.total,
    required this.mostrandoTotal,
    required this.coral,
    required this.coralSoft,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: mostrandoTotal
          ? Container(
              key: const ValueKey('total_on'),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    coral.withOpacity(.10),
                    coralSoft.withOpacity(.10),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: coral.withOpacity(.20)),
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [coral, const Color(0xFFFC5C7D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: const Icon(Icons.paid,
                        size: 24, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Total mensual',
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '\$${total.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(key: ValueKey('total_off')),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Color coral;
  final Color coralSoft;
  const _EmptyState({required this.coral, required this.coralSoft});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [coral, const Color(0xFFFC5C7D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                    color: coral.withOpacity(0.25),
                    blurRadius: 22,
                    offset: const Offset(0, 10))
              ],
            ),
            child: const Icon(Icons.subscriptions,
                size: 38, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            "No tienes suscripciones activas",
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            "Toca el botón salmón de abajo para agregar tu primera suscripción.",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}

class _EditorSuscripcion extends StatefulWidget {
  final TextEditingController nombreCtrl;
  final TextEditingController montoCtrl;
  final Color coral;
  final Color coralSoft;
  final IconData iconoInicial;
  final int diaInicial;
  final ValueChanged<int> onDiaChanged;
  final ValueChanged<IconData> onIconChanged;
  final VoidCallback onGuardar;

  const _EditorSuscripcion({
    required this.nombreCtrl,
    required this.montoCtrl,
    required this.coral,
    required this.coralSoft,
    required this.iconoInicial,
    required this.diaInicial,
    required this.onDiaChanged,
    required this.onIconChanged,
    required this.onGuardar,
  });

  @override
  State<_EditorSuscripcion> createState() => _EditorSuscripcionState();
}

class _EditorSuscripcionState extends State<_EditorSuscripcion> {
  late int _diaPago;
  late IconData _icono;

  @override
  void initState() {
    super.initState();
    _diaPago = widget.diaInicial;
    _icono = widget.iconoInicial;
  }

  @override
  Widget build(BuildContext context) {
    final favoritos = [5, 10, 15, 20, 25];
    final esUltimo = _diaPago == 31;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Editar suscripción',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        TextField(
          controller: widget.nombreCtrl,
          decoration: InputDecoration(
            labelText: 'Nombre',
            prefixIcon: Icon(Icons.edit, color: widget.coral),
            filled: true,
            fillColor: const Color(0xFFF9F9F9),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: widget.coral, width: 1)),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: widget.montoCtrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Monto (\$)',
            prefixIcon: Icon(Icons.attach_money, color: widget.coral),
            filled: true,
            fillColor: const Color(0xFFF9F9F9),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: widget.coral, width: 1)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            GestureDetector(
              onTap: () async {
                final nuevo = await showModalBottomSheet<IconData>(
                  context: context,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24))),
                  builder: (ctx) {
                    final opciones = const [
                      Icons.movie,
                      Icons.music_note,
                      Icons.tv,
                      Icons.book,
                      Icons.cloud,
                      Icons.gamepad,
                      Icons.sports_esports,
                      Icons.fitness_center,
                      Icons.fastfood,
                      Icons.wifi,
                      Icons.subscriptions
                    ];
                    return SafeArea(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Wrap(
                          spacing: 18,
                          runSpacing: 18,
                          children: opciones.map((ic) {
                            final selected = ic == _icono;
                            return InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => Navigator.pop(ctx, ic),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: selected
                                      ? LinearGradient(
                                          colors: [
                                            widget.coralSoft,
                                            widget.coral
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight)
                                      : null,
                                  color: selected
                                      ? null
                                      : Colors.grey[100],
                                ),
                                child: Icon(ic,
                                    color: selected
                                        ? Colors.white
                                        : widget.coral,
                                    size: 26),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                );
                if (nuevo != null) {
                  setState(() => _icono = nuevo);
                  widget.onIconChanged(nuevo);
                }
              },
              child: Container(
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: [widget.coralSoft, widget.coral],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight)),
                padding: const EdgeInsets.all(14),
                child: Icon(_icono, color: Colors.white, size: 26),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SelectorDia(
                coral: widget.coral,
                coralSoft: widget.coralSoft,
                dia: _diaPago,
                favoritos: favoritos,
                onChanged: (d) {
                  setState(() => _diaPago = d);
                  widget.onDiaChanged(d);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            esUltimo
                ? 'Cobro configurado para el último día de cada mes.'
                : 'Si un mes tiene menos días, se usará el último disponible automáticamente.',
            style: GoogleFonts.poppins(
                fontSize: 12, color: Colors.grey[700]),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar', style: GoogleFonts.poppins()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: widget.coral,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: widget.onGuardar,
                child: Text(
                  'Guardar',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SelectorDia extends StatelessWidget {
  final Color coral;
  final Color coralSoft;
  final int dia;
  final List<int> favoritos;
  final ValueChanged<int> onChanged;

  const _SelectorDia({
    required this.coral,
    required this.coralSoft,
    required this.dia,
    required this.favoritos,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget chipFavorito(int d, {String? label}) {
      final selected = dia == d;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label ?? '$d',
              style:
                  GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          selected: selected,
          onSelected: (v) {
            if (!v) return;
            HapticFeedback.selectionClick();
            onChanged(d);
          },
          selectedColor: coral,
          labelStyle:
              TextStyle(color: selected ? Colors.white : Colors.black87),
          backgroundColor: const Color(0xFFF9F9F9),
          shape: StadiumBorder(
              side: BorderSide(color: coral.withOpacity(.35))),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Día de cobro',
            style: GoogleFonts.poppins(
                fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final f in favoritos) chipFavorito(f),
            chipFavorito(31, label: 'Último día')
          ]),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8),
          itemCount: 28,
          itemBuilder: (context, i) {
            final d = i + 1;
            final selected = dia == d;
            return InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(d);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: selected
                      ? LinearGradient(
                          colors: [coralSoft, coral],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight)
                      : null,
                  color: selected ? null : Colors.white,
                  border: Border.all(
                      color:
                          selected ? coral : coral.withOpacity(.28),
                      width: 1.1),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                              color: coral.withOpacity(0.22),
                              blurRadius: 10,
                              offset: const Offset(0, 3))
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text('$d',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white
                            : Colors.black87)),
              ),
            );
          },
        ),
      ],
    );
  }
}
