import 'package:flutter/material.dart';
import 'pantallas/inicio.dart';
import 'widgets/calendario_gastos.dart';
import 'widgets/suscripciones.dart';
import 'modelos/suscripcion.dart';

void main() {
  runApp(const MiAppGastos());
}

class MiAppGastos extends StatelessWidget {
  const MiAppGastos({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App de Gastos',
      theme: ThemeData(
        // Puedes cambiar el color base aquí si quieres
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final PageController _pageController = PageController(initialPage: 1);
  int _currentPage = 1;

  // Estado global de suscripciones
  final List<Suscripcion> _suscripciones = [];

  // Token para refrescar el calendario cuando hay cambios
  int _calRefreshToken = 0;

  void _notificarCambio() {
    setState(() {
      _calRefreshToken++;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentPage = index),
        children: [
          // Izquierda: Suscripciones
          SuscripcionesScreen(
            suscripciones: _suscripciones,
            onChanged: _notificarCambio,
          ),
          // Centro: Inicio
          PantallaInicio(onCambioDatos: _notificarCambio),
          // Derecha: Calendario
          CalendarioGastos(
            suscripciones: _suscripciones,
            refreshToken: _calRefreshToken,
          ),
        ],
      ),
      // Eliminado el FAB verde
    );
  }
}

