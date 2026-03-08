import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class GraficoBarras extends StatefulWidget {
  final List<Map<String, dynamic>> datos;
  const GraficoBarras({super.key, required this.datos});

  @override
  State<GraficoBarras> createState() => _GraficoBarrasState();
}

class _GraficoBarrasState extends State<GraficoBarras> {
  int touchedIndex = -1;

  static const Map<String, IconData> _iconosCategoria = {
    'Comida': Icons.fastfood,
    'Transporte': Icons.directions_car,
    'Ropa': Icons.shopping_bag,
    'Entretenimiento': Icons.movie,
    'Café': Icons.coffee,
    'Uber': Icons.local_taxi,
    'Salud': Icons.healing,
    'Educación': Icons.school,
    'Tecnología': Icons.devices,
    'Mascotas': Icons.pets,
    'Otros': Icons.more_horiz,
  };

  IconData _getIcon(String categoria) =>
      _iconosCategoria[categoria] ?? Icons.category;

  final List<Color> _palette = const [
    Color(0xFF00A391),
    Color(0xFF6C63FF),
    Color(0xFFFF7A59),
    Color(0xFF2E86DE),
    Color(0xFFFFC107),
    Color(0xFF26A69A),
    Color(0xFF8E44AD),
    Color(0xFF00B894),
    Color(0xFFEE5253),
    Color(0xFF10AC84),
    Color(0xFF546E7A),
    Color(0xFFFF9F43),
  ];

  Color _barColorFor(int index) => _palette[index % _palette.length];

  @override
  Widget build(BuildContext context) {
    final datos = widget.datos;
    if (datos.isEmpty) return const SizedBox(height: 140);

    final double maxValor = datos
        .map((e) => (e['valor'] as num).toDouble())
        .reduce((a, b) => a > b ? a : b);
    final double maxY = maxValor > 0 ? (maxValor * 1.15) : 40;

    // --- Ajuste para evitar overflow abajo ---
    final scale = MediaQuery.of(context).textScaleFactor.clamp(1.0, 1.3);
    // 4 (padding top) + 26 (círculo) + 4 (espacio) + 12*scale (texto) + 6 margen
    final reservedBottom = (4 + 26 + 4 + 12 * scale + 6).roundToDouble();

    return AspectRatio(
      aspectRatio: 1.55,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          groupsSpace: 14,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: Colors.black12, strokeWidth: 0.6),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: reservedBottom, // <--- clave
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= datos.length) return const SizedBox.shrink();
                  final cat = (datos[i]['categoria'] as String?) ?? 'Otros';
                  final color = _barColorFor(i);
                  return Padding(
                    padding: const EdgeInsets.only(top: 4), // era 8
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 26, // era 28
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withOpacity(0.16),
                            border:
                                Border.all(color: color.withOpacity(0.5), width: 1),
                          ),
                          child: Icon(_getIcon(cat), size: 16, color: color),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cat.length > 4 ? '${cat.substring(0, 4)}.' : cat,
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1.0, // compacta la línea
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            handleBuiltInTouches: false,
            touchCallback: (evt, resp) {
              if (resp == null || resp.spot == null) {
                setState(() => touchedIndex = -1);
                return;
              }
              if (evt.isInterestedForInteractions) {
                setState(() => touchedIndex = resp.spot!.touchedBarGroupIndex);
              } else {
                setState(() => touchedIndex = -1);
              }
            },
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: Colors.black.withOpacity(0.85),
              tooltipRoundedRadius: 12,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (group, i, rod, r) {
                final cat = (datos[i]['categoria'] as String?) ?? 'Otros';
                final valor = (datos[i]['valor'] as num).toDouble();
                return BarTooltipItem(
                  '\$${valor.toStringAsFixed(2)}\n',
                  const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700),
                  children: [
                    TextSpan(
                      text: cat,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          barGroups: List.generate(datos.length, (i) {
            final valor = (datos[i]['valor'] as num).toDouble();
            final baseColor = _barColorFor(i);
            final isTouched = i == touchedIndex;

            final gradient = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                baseColor.withOpacity(isTouched ? 0.95 : 0.85),
                _darken(baseColor, 0.10),
              ],
            );

            return BarChartGroupData(
              x: i,
              showingTooltipIndicators: isTouched ? [0] : [],
              barRods: [
                BarChartRodData(
                  toY: valor,
                  width: isTouched ? 22 : 18,
                  borderRadius: BorderRadius.circular(8),
                  gradient: gradient,
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY,
                    color: baseColor.withOpacity(0.06),
                  ),
                ),
              ],
            );
          }),
        ),
        swapAnimationDuration: const Duration(milliseconds: 420),
        swapAnimationCurve: Curves.easeOutCubic,
      ),
    );
  }

  Color _darken(Color c, double amount) {
    final f = 1 - amount;
    return Color.fromARGB(
      c.alpha,
      (c.red * f).round(),
      (c.green * f).round(),
      (c.blue * f).round(),
    );
  }
}

