import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

class DialogAgregarSuscripcion extends StatefulWidget {
  final void Function(String nombre, double monto, IconData icono, int diaPago)? onGuardar;

  const DialogAgregarSuscripcion({super.key, this.onGuardar});

  @override
  State<DialogAgregarSuscripcion> createState() => _DialogAgregarSuscripcionState();
}

class _DialogAgregarSuscripcionState extends State<DialogAgregarSuscripcion> {
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _montoCtrl = TextEditingController();


  static const Color coral = Color(0xFFFF6464);
  static const Color coralSoft = Color(0xFFFFB2B2);

  IconData? _iconoSeleccionado = Icons.subscriptions;

  // Usamos 31 para representar "Último día del mes"
  int _diaPago = (() {
    final d = DateTime.now().day;
    return d > 28 ? 31 : d;
  })();

  bool _cargando = false;
  String _feedback = '';

  final List<Map<String, dynamic>> _iconos = const [
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

  // ===== Icon picker con tema coral =====
  void _abrirSelectorIcono() async {
    final icono = await showModalBottomSheet<IconData>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text("Selecciona un ícono",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: _iconos.map((icon) {
                    final ic = icon['icono'] as IconData;
                    final label = icon['label'] as String;
                    final selected = _iconoSeleccionado == ic;
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(ctx, ic);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: selected
                                  ? const LinearGradient(
                                      colors: [coralSoft, coral],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: selected ? null : Colors.grey[100],
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              ic,
                              color: selected ? Colors.white : coral,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(label, style: GoogleFonts.poppins(fontSize: 12.5)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
    if (icono != null) setState(() => _iconoSeleccionado = icono);
  }

  // ===== Guardar =====
  Future<void> _guardarSuscripcion() async {
    FocusScope.of(context).unfocus();
    final nombre = _nombreCtrl.text.trim();
    final montoText = _montoCtrl.text.replaceAll(',', '.').trim();
    final monto = double.tryParse(montoText);

    if (nombre.isEmpty || monto == null || monto <= 0) {
      setState(() => _feedback = 'Completa el nombre y un monto válido.');
      return;
    }
    setState(() {
      _cargando = true;
      _feedback = '';
    });

    await Future.delayed(const Duration(milliseconds: 600));

    widget.onGuardar?.call(
      nombre,
      monto,
      _iconoSeleccionado ?? Icons.subscriptions,
      _diaPago,
    );

    setState(() => _feedback = '¡Suscripción guardada!');
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) Navigator.pop(context);
  }

  // ===== Chips auxiliares =====
  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: coral.withOpacity(.3)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: GoogleFonts.poppins(
              fontSize: 12.5, fontWeight: FontWeight.w600, color: coral)),
    );
  }

  // ===== Selector de día =====
  Widget _buildDiaPicker() {
    final favoritos = [5, 10, 15, 20, 25];
    final esUltimo = _diaPago == 31;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 18, color: coral),
            const SizedBox(width: 8),
            Text('Día de cobro',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            const Spacer(),
            _pill(esUltimo ? 'Último día' : 'Día $_diaPago'),
          ],
        ),
        const SizedBox(height: 10),

        // Atajos de favoritos
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final d in favoritos)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('$d', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                    selected: _diaPago == d,
                    onSelected: _cargando ? null : (v) {
                      if (!v) return;
                      HapticFeedback.selectionClick();
                      setState(() => _diaPago = d);
                    },
                    selectedColor: coral,
                    labelStyle: TextStyle(color: _diaPago == d ? Colors.white : Colors.black87),
                    backgroundColor: const Color(0xFFF9F9F9),
                    shape: StadiumBorder(side: BorderSide(color: coral.withOpacity(.35))),
                  ),
                ),
              // Opción especial: Último día
              ChoiceChip(
                label: Text('Último día', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                selected: esUltimo,
                onSelected: _cargando ? null : (v) {
                  if (!v) return;
                  HapticFeedback.selectionClick();
                  setState(() => _diaPago = 31); // se ajusta luego al lastDay
                },
                selectedColor: coral,
                labelStyle: TextStyle(color: esUltimo ? Colors.white : Colors.black87),
                backgroundColor: const Color(0xFFF9F9F9),
                shape: StadiumBorder(side: BorderSide(color: coral.withOpacity(.35))),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Cuadrícula 1–28
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: 28,
          itemBuilder: (context, i) {
            final day = i + 1;
            final selected = _diaPago == day;
            return InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: _cargando
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      setState(() => _diaPago = day);
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: selected
                      ? const LinearGradient(
                          colors: [coralSoft, coral],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: selected ? null : Colors.white,
                  border: Border.all(
                    color: selected ? coral : coral.withOpacity(.28),
                    width: 1.2,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: coral.withOpacity(0.22),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$day',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Si un mes tiene menos días, la app usará el último disponible automáticamente.',
          style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey[700]),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      elevation: 10,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Agregar suscripción',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          letterSpacing: .2,
                        ),
                      ),
                    ),
                    IconButton(
                      splashRadius: 22,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: coral),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Ej: Netflix, Spotify, Amazon Prime…',
                    style: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 13.5),
                  ),
                ),
                const SizedBox(height: 16),

                // Icono (gradiente coral)
                GestureDetector(
                  onTap: _cargando ? null : _abrirSelectorIcono,
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [coralSoft, coral],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: coral.withOpacity(0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Icon(
                          _iconoSeleccionado ?? Icons.subscriptions,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Selecciona ícono',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Nombre
                TextField(
                  controller: _nombreCtrl,
                  enabled: !_cargando,
                  style: GoogleFonts.poppins(fontSize: 16.5, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Netflix, Spotify…',
                    filled: true,
                    fillColor: const Color(0xFFF9F9F9),
                    prefixIcon: const Icon(Icons.edit, color: coral),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: coral.withOpacity(.28), width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: coral, width: 1.8),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Monto
                TextField(
                  controller: _montoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  enabled: !_cargando,
                  style: GoogleFonts.poppins(fontSize: 16.5, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    labelText: 'Monto mensual (\$)',
                    hintText: 'Ej: 10',
                    filled: true,
                    fillColor: const Color(0xFFF9F9F9),
                    prefixIcon: const Icon(Icons.attach_money, color: coral),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: coral.withOpacity(.28), width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: coral, width: 1.8),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Selector de día (favoritos + grid + último día)
                _buildDiaPicker(),

                const SizedBox(height: 18),

                // Botón guardar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _cargando ? null : _guardarSuscripcion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: coral,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 2,
                      textStyle: GoogleFonts.poppins(fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                    icon: _cargando
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                          )
                        : const Icon(Icons.check_rounded, size: 20),
                    label: Text(_cargando ? '' : 'Guardar suscripción'),
                  ),
                ),

                if (_feedback.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: coral.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _feedback,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
