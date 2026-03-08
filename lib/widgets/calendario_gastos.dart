import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';

import '../servicios/base_datos.dart';
import '../modelos/gasto.dart';
import '../modelos/suscripcion.dart';

class CalendarioGastos extends StatefulWidget {
  /// Ya no dependemos de esta lista para renderizar; puede venir vacía.
  final List<Suscripcion> suscripciones;
  final int refreshToken;

  const CalendarioGastos({
    super.key,
    required this.suscripciones,
    required this.refreshToken,
  });

  @override
  State<CalendarioGastos> createState() => _CalendarioGastosState();
}

class _CalendarioGastosState extends State<CalendarioGastos> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _format = CalendarFormat.month;

  Map<DateTime, List<Gasto>> _gastosPorFecha = {};
  List<Suscripcion> _suscripciones = []; // <-- cargadas desde DB
  int? _pressedIndex;
  bool _isBouncing = false;

  static const Map<String, Color> _categoriaColor = {
    'comida': Color(0xFF2563EB),
    'transporte': Color(0xFF14B8A6),
    'uber': Color(0xFF0EA5E9),
    'ropa': Color(0xFF9333EA),
    'entretenimiento': Color(0xFFF59E0B),
    'café': Color(0xFFEA580C),
    'salud': Color(0xFFEF4444),
    'educación': Color(0xFF10B981),
    'tecnología': Color(0xFF64748B),
    'mascotas': Color(0xFF9CA3AF),
  };

  @override
  void initState() {
    super.initState();
    _loadGastosParaMes(_focusedDay.year, _focusedDay.month);
  }

  @override
  void didUpdateWidget(covariant CalendarioGastos oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      // Si alguien pulsó "onChanged" desde Suscripciones, recargamos mes y suscripciones desde DB
      _loadGastosParaMes(_focusedDay.year, _focusedDay.month);
    }
  }

  Future<void> _loadGastosParaMes(int year, int month) async {
    // Traemos todo desde BD para este mes y las suscripciones actuales.
    final gastos = await BaseDatos.obtenerGastosDelMes(year, month);
    final suscripcionesDB = await BaseDatos.obtenerSuscripciones();

    final map = <DateTime, List<Gasto>>{};
    for (final g in gastos) {
      final local = DateTime(g.fecha.year, g.fecha.month, g.fecha.day);
      if (local.year == year && local.month == month) {
        final key = DateTime.utc(local.year, local.month, local.day);
        map.putIfAbsent(key, () => []).add(g);
      }
    }

    // Proyectar suscripciones
    final lastDay = DateTime(year, month + 1, 0).day;
    for (final sub in suscripcionesDB) {
      final diaPago = (sub.diaPago == 31) ? lastDay : (sub.diaPago <= lastDay ? sub.diaPago : lastDay);
      final fechaPagoLocal = DateTime(year, month, diaPago);
      final key = DateTime.utc(fechaPagoLocal.year, fechaPagoLocal.month, fechaPagoLocal.day);

      final yaExiste = (map[key]?.any((g) =>
            g.categoria.toLowerCase() == sub.nombre.toLowerCase() &&
            (g.monto - sub.monto).abs() < 0.0001)) ?? false;

      if (!yaExiste) {
        map.putIfAbsent(key, () => []).add(
          Gasto(id: null, monto: sub.monto, categoria: sub.nombre, fecha: fechaPagoLocal),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _suscripciones = suscripcionesDB;
      _gastosPorFecha = map;
    });
  }

  List<Gasto> _getGastosDelDia(DateTime day) {
    final key = DateTime.utc(day.year, day.month, day.day);
    return _gastosPorFecha[key] ?? [];
  }

  List<Gasto> _eventLoader(DateTime day) => _getGastosDelDia(day);

  IconData _getIconoCategoria(String categoria) {
    switch (categoria.toLowerCase()) {
      case 'comida':
        return Icons.fastfood;
      case 'transporte':
        return Icons.directions_car;
      case 'ropa':
        return Icons.shopping_bag;
      case 'entretenimiento':
        return Icons.movie;
      case 'café':
        return Icons.coffee;
      case 'uber':
        return Icons.local_taxi;
      case 'salud':
        return Icons.local_hospital;
      case 'educación':
        return Icons.school;
      case 'tecnología':
        return Icons.devices;
      case 'mascotas':
        return Icons.pets;
      default:
        final sub = _suscripciones.firstWhere(
          (s) => s.nombre.toLowerCase() == categoria.toLowerCase(),
          orElse: () => Suscripcion(
            nombre: 'Otro', monto: 0, icono: Icons.subscriptions, diaPago: 1),
        );
        return sub.icono;
    }
  }

  Color _colorCategoria(String categoria) {
    return _categoriaColor[categoria.toLowerCase()] ?? const Color(0xFF111827);
  }

  String _descripcionCategoria(String categoria) {
    final c = categoria.toLowerCase();
    if (c == 'comida') return 'Gasto típico en alimentos y bebidas del día a día.';
    if (c == 'transporte' || c == 'uber') return 'Traslados, taxis o transporte público.';
    if (c == 'ropa') return 'Compra de prendas, calzado o accesorios.';
    if (c == 'entretenimiento') return 'Cine, streaming, conciertos u ocio.';
    if (c == 'café') return 'Cafetería o bebidas calientes.';
    if (c == 'salud') return 'Medicamentos, consultas o seguros.';
    if (c == 'educación') return 'Cursos, matrículas, libros o materiales.';
    if (c == 'tecnología') return 'Gadgets, suscripciones o apps.';
    if (c == 'mascotas') return 'Alimento, veterinario o accesorios para tu mascota.';
    return 'Pago registrado en la categoría "$categoria".';
  }

  String _formatFecha(DateTime f) {
    final dd = f.day.toString().padLeft(2, '0');
    final mm = f.month.toString().padLeft(2, '0');
    final yyyy = f.year.toString();
    return '$dd/$mm/$yyyy';
  }

  bool _esSuscripcionProyectada(Gasto g) {
    if (g.id == null) return true;
    return _suscripciones.any((s) =>
      s.nombre.toLowerCase() == g.categoria.toLowerCase() &&
      (s.monto - g.monto).abs() < 0.0001
    );
  }

  Future<void> _mostrarDetalleGasto(Gasto gasto) async {
    HapticFeedback.lightImpact();
    final esSub = _esSuscripcionProyectada(gasto);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          tween: Tween(begin: 0.95, end: 1),
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, alignment: Alignment.bottomCenter, child: child);
          },
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 38, height: 4, margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: _colorCategoria(gasto.categoria).withOpacity(0.1),
                      child: Icon(_getIconoCategoria(gasto.categoria), color: _colorCategoria(gasto.categoria)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(gasto.categoria, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(_descripcionCategoria(gasto.categoria), style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey[700])),
                      ]),
                    ),
                    Text('\$${gasto.monto.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 6),
                  Text('Registrado el ${_formatFecha(gasto.fecha)}', style: GoogleFonts.poppins(fontSize: 12.5)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.info_outline, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      esSub
                        ? 'Esta es una suscripción proyectada. Para editar o eliminar, hazlo en la ventana de Suscripciones.'
                        : 'Tip: mantén presionado para Editar / Eliminar.',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    final msg = '\$${gasto.monto.toStringAsFixed(2)} • ${gasto.categoria} • ${_formatFecha(gasto.fecha)}';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, style: GoogleFonts.poppins()),
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  Future<void> _rebote(int index) async {
    if (_isBouncing) return;
    _isBouncing = true;
    setState(() => _pressedIndex = index);
    await Future.delayed(const Duration(milliseconds: 70));
    setState(() => _pressedIndex = null);
    await Future.delayed(const Duration(milliseconds: 40));
    setState(() => _pressedIndex = index);
    await Future.delayed(const Duration(milliseconds: 60));
    setState(() => _pressedIndex = null);
    _isBouncing = false;
  }

  Future<void> _onLongPressGasto(Gasto gasto, int index) async {
    final esSub = _esSuscripcionProyectada(gasto);
    HapticFeedback.mediumImpact();
    await _rebote(index);

    if (esSub) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Este ítem viene de una suscripción. Para editar o eliminar, usa la ventana de Suscripciones.',
              style: GoogleFonts.poppins(),
            ),
            duration: const Duration(milliseconds: 2500),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      return;
    }

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
                title: Text('Editar', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _editarGasto(gasto);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: Text('Eliminar', style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmarEliminar(gasto);
                },
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  void _confirmarEliminar(Gasto gasto) {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar gasto', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          '¿Seguro que deseas eliminar este gasto?\n\n${gasto.categoria} • \$${gasto.monto.toStringAsFixed(2)} • ${_formatFecha(gasto.fecha)}',
          style: GoogleFonts.poppins(),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar', style: GoogleFonts.poppins())),
          FilledButton.tonal(
            onPressed: () async {
              Navigator.pop(context);
              await _eliminarGastoDB(gasto);
            },
            child: Text('Eliminar', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminarGastoDB(Gasto gasto) async {
    try {
      if (gasto.id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Este ítem es una suscripción proyectada. Edítalo en Suscripciones.', style: GoogleFonts.poppins()),
            duration: const Duration(milliseconds: 1600),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }
      await BaseDatos.eliminarGasto(gasto.id!);
      await _loadGastosParaMes(_focusedDay.year, _focusedDay.month);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gasto eliminado', style: GoogleFonts.poppins()),
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo eliminar: $e', style: GoogleFonts.poppins()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editarGasto(Gasto gasto) async {
    HapticFeedback.lightImpact();
    final montoCtrl = TextEditingController(text: gasto.monto.toStringAsFixed(2));
    final categoriaCtrl = TextEditingController(text: gasto.categoria);
    DateTime fechaTmp = gasto.fecha;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16, left: 16, right: 16, top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Editar gasto', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: montoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monto', prefixText: '\$ '),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: categoriaCtrl,
                decoration: const InputDecoration(labelText: 'Categoría'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18),
                  const SizedBox(width: 8),
                  Text(_formatFecha(fechaTmp), style: GoogleFonts.poppins()),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: fechaTmp,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        fechaTmp = DateTime(picked.year, picked.month, picked.day);
                        (context as Element).markNeedsBuild();
                      }
                    },
                    child: Text('Cambiar', style: GoogleFonts.poppins()),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancelar', style: GoogleFonts.poppins()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final monto = double.tryParse(montoCtrl.text.replaceAll(',', '.'));
                        final categoria = categoriaCtrl.text.trim();
                        if (monto == null || monto <= 0 || categoria.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Revisa monto/categoría', style: GoogleFonts.poppins())));
                          return;
                        }
                        final editado = gasto.copyWith(monto: monto, categoria: categoria, fecha: fechaTmp);
                        Navigator.pop(context);
                        await _actualizarGastoDB(editado, gasto.fecha);
                      },
                      child: Text('Guardar', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _actualizarGastoDB(Gasto editado, DateTime _) async {
    try {
      if (editado.id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Este ítem no está en DB (suscripción proyectada).', style: GoogleFonts.poppins())),
        );
        return;
      }
      await BaseDatos.actualizarGasto(editado);
      await _loadGastosParaMes(_focusedDay.year, _focusedDay.month);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gasto actualizado', style: GoogleFonts.poppins()),
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: $e', style: GoogleFonts.poppins())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final diaActual = _selectedDay ?? _focusedDay;
    final gastosDelDia = _getGastosDelDia(diaActual);
    final totalDia = gastosDelDia.fold<double>(0.0, (a, b) => a + b.monto);

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: mes y selector de formato
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Mes anterior',
                  splashRadius: 20,
                  onPressed: () {
                    final prev = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
                    setState(() => _focusedDay = prev);
                    _loadGastosParaMes(prev.year, prev.month);
                  },
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${_nombreMes(_focusedDay.month)} ${_focusedDay.year}',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Mes siguiente',
                  splashRadius: 20,
                  onPressed: () {
                    final next = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
                    setState(() => _focusedDay = next);
                    _loadGastosParaMes(next.year, next.month);
                  },
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<CalendarFormat>(
              segments: const [
                ButtonSegment(value: CalendarFormat.month, label: Text('Mes')),
                ButtonSegment(value: CalendarFormat.twoWeeks, label: Text('2 semanas')),
              ],
              selected: <CalendarFormat>{_format},
              onSelectionChanged: (v) => setState(() => _format = v.first),
              showSelectedIcon: false,
              style: ButtonStyle(
                textStyle: WidgetStatePropertyAll(GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ),
          ),

          // Calendario
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TableCalendar(
                focusedDay: _focusedDay,
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2100, 12, 31),
                calendarFormat: _format,
                startingDayOfWeek: StartingDayOfWeek.sunday,
                headerVisible: false,
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                  weekendStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                ),
                calendarStyle: CalendarStyle(
                  cellMargin: const EdgeInsets.all(6),
                  outsideDaysVisible: false,
                  defaultTextStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                  weekendTextStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                  todayDecoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 1.4),
                    color: Colors.transparent,
                  ),
                  todayTextStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w700),
                  selectedDecoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  selectedTextStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
                  outsideTextStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                ),
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: _eventLoader,
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focused) => _dayCellBase(day),
                  todayBuilder: (context, day, focused) => _dayCellBase(day, isToday: true),
                  selectedBuilder: (context, day, focused) => _dayCellBase(day, isSelected: true),
                  markerBuilder: (context, day, events) {
                    if (events.isEmpty) return const SizedBox.shrink();
                    final count = events.length.clamp(1, 3);
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(count, (i) {
                            return Container(
                              width: 5, height: 5,
                              margin: EdgeInsets.only(left: i == 0 ? 0 : 3),
                              decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                            );
                          }),
                        ),
                      ),
                    );
                  },
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                  _loadGastosParaMes(focusedDay.year, focusedDay.month);
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Resumen del día
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Text('Gastos del ${_formatFecha(diaActual)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
                  const Spacer(),
                  _chip('${gastosDelDia.length} ítem${gastosDelDia.length == 1 ? '' : 's'}'),
                  const SizedBox(width: 8),
                  _chip('\$${totalDia.toStringAsFixed(2)}'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Lista del día
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: gastosDelDia.isEmpty
                  ? Center(child: Text('Sin gastos registrados.', style: GoogleFonts.poppins(color: Colors.grey[600])))
                  : ListView.separated(
                      itemCount: gastosDelDia.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final gasto = gastosDelDia[index];
                        final leadingColor = _colorCategoria(gasto.categoria);

                        final card = AnimatedScale(
                          duration: const Duration(milliseconds: 120),
                          scale: _pressedIndex == index ? 0.98 : 1.0,
                          curve: Curves.easeOut,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42, height: 42,
                                  decoration: BoxDecoration(color: leadingColor.withOpacity(0.12), shape: BoxShape.circle),
                                  child: Icon(_getIconoCategoria(gasto.categoria), color: leadingColor),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(gasto.categoria, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                      Text(_formatFecha(gasto.fecha), style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                                    ],
                                  ),
                                ),
                                Text('\$${gasto.monto.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        );

                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () async {
                            setState(() => _pressedIndex = index);
                            await Future.delayed(const Duration(milliseconds: 70));
                            setState(() => _pressedIndex = null);
                            _mostrarDetalleGasto(gasto);
                          },
                          onTapDown: (_) => setState(() => _pressedIndex = index),
                          onTapCancel: () => setState(() => _pressedIndex = null),
                          onLongPress: () => _onLongPressGasto(gasto, index),
                          child: card,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== helpers visuales =====

  Widget _dayCellBase(DateTime day, {bool isToday = false, bool isSelected = false}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isSelected)
            Container(width: 36, height: 36, decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle)),
          if (isToday && !isSelected)
            Container(width: 34, height: 34, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 1.3))),
          Text(
            '${day.day}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _nombreMes(int m) {
    const meses = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
    return meses[m - 1];
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(text, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 0.2)),
    );
  }
}
