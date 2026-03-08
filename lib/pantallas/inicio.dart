import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/grafico_barras.dart';
import 'dialog_agregar_gasto.dart';
import '../modelos/gasto.dart';
import '../servicios/base_datos.dart';

class PantallaInicio extends StatefulWidget {
  final VoidCallback onCambioDatos;

  const PantallaInicio({super.key, required this.onCambioDatos});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  List<Gasto> gastos = [];

  final List<String> _consejos = [
    "Registrar tus gastos diarios te ayuda a ahorrar más.",
    "¡Haz tu propio presupuesto mensual y síguelo!",
    "¿Sabías que anotar hasta los gastos pequeños hace una gran diferencia?",
    "Revisa tus gastos al final de cada semana para identificar oportunidades de ahorro.",
    "Evita compras impulsivas preguntándote: ¿realmente lo necesito?",
    "Ponle nombre a tus metas de ahorro, te será más fácil cumplirlas.",
    "Comparte tus objetivos financieros con alguien de confianza, eso te motiva.",
    "Revisa tus suscripciones: a veces pagamos por servicios que ya no usamos.",
    "Tener un fondo de emergencia te da tranquilidad y control.",
    "Una app como SKULL puede ser tu mejor aliada para entender tus finanzas.",
    "Aprovecha descuentos solo si ya planeabas comprar ese producto.",
    "Recuerda: ¡cada peso cuenta!",
    "Aprender de tus gastos es el primer paso para una mejor salud financiera.",
    "Las pequeñas mejoras diarias suman grandes resultados en el tiempo.",
    "¡Controlar tus gastos es una forma de autocuidado!"
  ];

  int _consejoActual = 0;
  Timer? _timer;
  double _opacity = 1.0;

  // Easter egg
  int _secretTapCount = 0;
  Timer? _secretResetTimer;

  @override
  void initState() {
    super.initState();
    _iniciarRotacionConsejos();
    _cargarGastos();
  }

  Future<void> _cargarGastos() async {
    final gastosDB = await BaseDatos.obtenerGastos();
    if (!mounted) return;
    setState(() {
      gastos = gastosDB;
    });
  }

  Future<void> _agregarGasto(double monto, String categoria, DateTime fecha) async {
    final nuevo = Gasto(monto: monto, categoria: categoria, fecha: fecha);
    await BaseDatos.insertarGasto(nuevo);
    await _cargarGastos();
    widget.onCambioDatos();
  }

  void _iniciarRotacionConsejos() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _mostrarSiguienteConsejo());
  }

  void _mostrarSiguienteConsejo({bool manual = false}) async {
    setState(() => _opacity = 0.0);
    await Future.delayed(const Duration(milliseconds: 330));
    setState(() {
      _consejoActual = (_consejoActual + 1) % _consejos.length;
      _opacity = 1.0;
    });
    if (manual) {
      _timer?.cancel();
      _iniciarRotacionConsejos();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _secretResetTimer?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> get datosCategorias {
    final now = DateTime.now();
    final Map<String, double> categorias = {};
    for (var g in gastos.where((g) => g.fecha.month == now.month && g.fecha.year == now.year)) {
      categorias[g.categoria] = (categorias[g.categoria] ?? 0) + g.monto;
    }
    return categorias.entries.map((e) => {'categoria': e.key, 'valor': e.value}).toList();
  }

  double get totalMes {
    final now = DateTime.now();
    return gastos
        .where((g) => g.fecha.month == now.month && g.fecha.year == now.year)
        .fold(0.0, (sum, g) => sum + g.monto);
  }

  double get totalHoy {
    final now = DateTime.now();
    return gastos
        .where((g) => g.fecha.year == now.year && g.fecha.month == now.month && g.fecha.day == now.day)
        .fold(0.0, (sum, g) => sum + g.monto);
  }

  // Lógica del Easter Egg
  void _onSecretTap() {
    _secretResetTimer?.cancel();
    _secretTapCount++;
    _secretResetTimer = Timer(const Duration(seconds: 2), () {
      _secretTapCount = 0;
    });

    if (_secretTapCount >= 10) {
      _secretTapCount = 0;
      _secretResetTimer?.cancel();
      _mostrarAgradecimientos();
    }
  }

  void _mostrarAgradecimientos() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Agradecimientos",
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, _, __) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Center(child: _AgradecimientosDialog(onClose: () => Navigator.of(context).pop())),
        );
      },
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // fuerza que no exista FAB (por si el tema o otra parte lo agrega)
      floatingActionButton: null,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: AppBar(
          backgroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          title: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'SKULL',
              style: GoogleFonts.poppins(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: Colors.black,
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 6, top: 6),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _onSecretTap,
                child: const SizedBox(width: 56, height: 56),
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Card(
              color: Colors.grey[100],
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text(
                      "Resumen de ${_nombreMes(DateTime.now().month)}",
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey[800]),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "\$${totalMes.toStringAsFixed(2)} gastado",
                      style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    Text(
                      "Hoy: \$${totalHoy.toStringAsFixed(2)}",
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            gastos.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Text(
                      "Aún no has registrado ningún gasto este mes.",
                      style: GoogleFonts.poppins(fontSize: 17, color: Colors.grey[700]),
                      textAlign: TextAlign.center,
                    ),
                  )
                : GraficoBarras(datos: datosCategorias),
            const SizedBox(height: 40),
            Center(
              child: GestureDetector(
                onTap: () {
                  showGeneralDialog(
                    context: context,
                    barrierLabel: "Agregar gasto",
                    barrierDismissible: true,
                    barrierColor: Colors.black38,
                    transitionDuration: const Duration(milliseconds: 320),
                    pageBuilder: (context, _, __) {
                      return BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                        child: Center(child: DialogAgregarGasto(onGastoAgregado: _agregarGasto)),
                      );
                    },
                    transitionBuilder: (ctx, anim, _, child) {
                      return FadeTransition(
                        opacity: anim,
                        child: Transform.scale(scale: 0.98 + (anim.value * 0.02), child: child),
                      );
                    },
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6464), Color(0xFFFC5C7D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.23),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  padding: const EdgeInsets.all(32),
                  child: const Icon(Icons.add, color: Colors.white, size: 36),
                ),
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => _mostrarSiguienteConsejo(manual: true),
              child: AnimatedOpacity(
                opacity: _opacity,
                duration: const Duration(milliseconds: 380),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lightbulb, color: Color(0xFFFF6464), size: 22),
                      const SizedBox(width: 9),
                      Flexible(
                        child: Text(
                          '"${_consejos[_consejoActual]}"',
                          style: GoogleFonts.poppins(fontSize: 15.5, color: Colors.grey[850], fontWeight: FontWeight.w500, height: 1.34),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.touch_app_rounded, color: Color(0xFFB1B1B1), size: 18),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }

  String _nombreMes(int mes) {
    const meses = [
      'Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'
    ];
    return meses[(mes - 1).clamp(0, 11)];
  }
}

class _AgradecimientosDialog extends StatelessWidget {
  final VoidCallback onClose;
  const _AgradecimientosDialog({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.90), Colors.white.withOpacity(0.82)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 24, offset: const Offset(0, 10)),
              ],
              border: Border.all(width: 1.2, color: const Color(0xFFFF6464).withOpacity(0.35)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF6464), Color(0xFFFC5C7D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.favorite_rounded, color: Colors.white),
                        const SizedBox(width: 10),
                        Text(
                          'Agradecimientos',
                          style: GoogleFonts.poppins(
                            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: .4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 340),
                      child: SingleChildScrollView(
                        child: Text(
                          'Hola soy Juan Diego, el creador de esta app. La verdad que es la primera vez que me aventuro a realizar una app como esta, '
                          'pero fue gracias a la inspiración de la chica más especial que he conocido, no se que vaya a pasar en un futuro pero si tú, '
                          'Valentina, llegas a leer esto, sepas que gracias a ti evolucioné en muchísimos aspectos, esta app es en honor a ti, porque como '
                          'ya lo dije una vez "Si me preguntan por todo lo que pasó, siempre diré que me equivoqué de vida, pero jamás de amor", '
                          'espero disfrutes de esta herramienta, princesa.',
                          textAlign: TextAlign.justify,
                          style: GoogleFonts.poppins(color: Colors.black87, fontSize: 15.5, height: 1.45),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xFFFF6464),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          shadowColor: const Color(0xFFFF6464).withOpacity(0.25),
                          elevation: 2,
                        ),
                        onPressed: onClose,
                        child: Text('Cerrar', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: -18,
            right: 18,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6464), Color(0xFFFC5C7D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.28), blurRadius: 16, offset: const Offset(0, 8))],
              ),
              child: const Icon(Icons.favorite, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

