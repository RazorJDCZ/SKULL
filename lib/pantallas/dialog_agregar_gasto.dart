import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class DialogAgregarGasto extends StatefulWidget {
  final void Function(double monto, String categoria, DateTime fecha)? onGastoAgregado;
  const DialogAgregarGasto({super.key, this.onGastoAgregado});

  @override
  State<DialogAgregarGasto> createState() => _DialogAgregarGastoState();
}

class _DialogAgregarGastoState extends State<DialogAgregarGasto> {
  final TextEditingController _controller = TextEditingController();
  bool _cargando = false;
  String _resultado = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // --- Normalización de categorías ---
  String normalizarCategoria(String categoria) {
    const mapeo = {
      'fastfood': 'Comida',
      'comidas': 'Comida',
      'alimentos': 'Comida',
      'taxi': 'Uber',
      'cabify': 'Uber',
      'uber': 'Uber',
      'ropa': 'Ropa',
      'clothes': 'Ropa',
      'cine': 'Entretenimiento',
      'movies': 'Entretenimiento',
      'entretenimiento': 'Entretenimiento',
      'cafe': 'Café',
      'coffee': 'Café',
      'salud': 'Salud',
      'medico': 'Salud',
      'doctor': 'Salud',
      'mascota': 'Mascotas',
      'mascotas': 'Mascotas',
      'veterinario': 'Mascotas',
      'educacion': 'Educación',
      'escuela': 'Educación',
      'tecnologia': 'Tecnología',
      'tecnologías': 'Tecnología',
      'otros': 'Otros',
    };
    categoria = categoria.trim().toLowerCase();
    return mapeo[categoria] ?? _capitalize(categoria);
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Future<void> _analizarGasto() async {
    final texto = _controller.text.trim();
    if (texto.isEmpty) return;

    setState(() {
      _cargando = true;
      _resultado = '';
    });

    try {
      final gastos = await analizarConOpenAI(texto);

      // 1) Fecha inferida local (hoy/ayer/anteayer/dd-mm-aaaa)
      final fechaInferida = _inferirFecha(texto);
      // 2) Si hay referencia relativa, preferimos SIEMPRE la fecha local
      final preferLocal = _tieneReferenciaRelativa(texto);

      if (gastos.isEmpty) {
        setState(() => _resultado = 'No se detectaron gastos. Prueba con otro texto.');
      } else {
        for (var g in gastos) {
          DateTime fecha = fechaInferida;

          // Usar fecha del modelo solo si NO hay referencia relativa
          final f = (g['fechaISO'] ?? g['fecha'] ?? '').toString().trim();
          if (!preferLocal && f.isNotEmpty) {
            try {
              fecha = DateTime.parse(f);
            } catch (_) {
              // Ignorar y mantener fechaInferida
            }
          }

          // Normalizamos a medianoche local para evitar problemas de TZ
          fecha = DateTime(fecha.year, fecha.month, fecha.day);

          widget.onGastoAgregado?.call(
            (g['monto'] is num ? (g['monto'] as num).toDouble() : 0.0),
            g['categoria'].toString(),
            fecha,
          );
        }
        setState(() {
          _resultado = 'Gasto${gastos.length > 1 ? "s" : ""} agregado${gastos.length > 1 ? "s" : ""} correctamente ✅';
        });
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _resultado = 'Ocurrió un error: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // --- Parser local simple de fechas en español ---
  DateTime _inferirFecha(String texto) {
    final now = DateTime.now();
    final low = texto.toLowerCase();

    if (low.contains('anteayer')) {
      return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 2));
    }
    if (low.contains('ayer')) {
      return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    }
    if (low.contains('hoy')) {
      return DateTime(now.year, now.month, now.day);
    }

    // dd/mm/yyyy o dd-mm-yyyy
    final r = RegExp(r'(\b\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})');
    final m = r.firstMatch(low);
    if (m != null) {
      final d = int.tryParse(m.group(1)!);
      final mo = int.tryParse(m.group(2)!);
      final y = int.tryParse(m.group(3)!);
      if (d != null && mo != null && y != null) {
        try {
          return DateTime(y, mo, d);
        } catch (_) {}
      }
    }

    // Si nada matchea, asume hoy (al nivel de fecha, sin horas)
    return DateTime(now.year, now.month, now.day);
  }

  bool _tieneReferenciaRelativa(String texto) {
    final t = texto.toLowerCase();
    return t.contains('ayer') || t.contains('anteayer') || t.contains('hoy');
  }

  Future<List<Map<String, dynamic>>> analizarConOpenAI(String texto) async {
    const openAiApiKey = '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'; 
    const endpoint = 'https://api.openai.com/v1/chat/completions';

    // Lista de categorías válidas
    const categoriasValidas = [
      "Comida", "Transporte", "Ropa", "Entretenimiento", "Café",
      "Uber", "Salud", "Educación", "Tecnología", "Mascotas", "Otros"
    ];

    final prompt = '''
Extrae los gastos del siguiente texto y asígnales una de estas categorías:
["Comida","Transporte","Ropa","Entretenimiento","Café","Uber","Salud","Educación","Tecnología","Mascotas","Otros"].

Devuelve SOLO JSON (un array). Cada elemento DEBE tener:
- "monto": número
- "categoria": una de las categorías válidas
- "fechaISO": fecha en formato ISO 8601 (YYYY-MM-DD) deducida del texto; si dice "ayer", usa la fecha de ayer respecto a hoy.

Ejemplo de salida:
[
  {"monto":12.5,"categoria":"Comida","fechaISO":"2025-08-10"},
  {"monto":6,"categoria":"Café","fechaISO":"2025-08-09"}
]

Texto: "$texto"
''';

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Authorization': 'Bearer $openAiApiKey',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'model': 'gpt-3.5-turbo',
        'messages': [
          {
            'role': 'system',
            'content': 'Eres un extractor de gastos. Extrae monto, categoría y una fecha ISO. Responde solo JSON.'
          },
          {'role': 'user', 'content': prompt},
        ],
        'max_tokens': 220,
        'temperature': 0.0,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Error de OpenAI: ${response.statusCode} ${response.body}');
    }

    // Tomar SOLO el content
    final decoded = json.decode(response.body) as Map<String, dynamic>;
    String content = (decoded['choices']?[0]?['message']?['content'] ?? '').toString().trim();
    if (content.isEmpty) throw const FormatException('Respuesta vacía del modelo');

    // Limpiar bloque ```json ... ```
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```', multiLine: true);
    final mFence = fence.firstMatch(content);
    if (mFence != null) content = mFence.group(1)!.trim();

    // Asegurar que sea un array
    if (content.startsWith('{') && content.endsWith('}')) {
      content = '[$content]';
    }

    List<dynamic>? gastosList;
    try {
      gastosList = json.decode(content) as List<dynamic>;
    } catch (_) {
      final arr = RegExp(r'\[\s*{[\s\S]*}\s*\]', multiLine: true);
      final mm = arr.firstMatch(content);
      if (mm == null) {
        throw const FormatException('No se encontró un array JSON válido en la respuesta');
      }
      gastosList = json.decode(mm.group(0)!) as List<dynamic>;
    }

    // Normalización
    final List<Map<String, dynamic>> resultado = [];
    for (final item in gastosList) {
      if (item is Map<String, dynamic>) {
        final montoRaw = item['monto'];
        double? monto = (montoRaw is num) ? montoRaw.toDouble() : double.tryParse('$montoRaw');
        String cat = (item['categoria'] ?? '').toString();
        String fechaISO = (item['fechaISO'] ?? '').toString().trim();

        if (monto == null || monto <= 0) continue;

        cat = normalizarCategoria(cat);
        if (!categoriasValidas.contains(cat)) cat = 'Otros';

        // Validar fechaISO: si vino "YYYY-MM-DD", lo pasamos a "YYYY-MM-DDT00:00:00"
        if (fechaISO.isNotEmpty && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(fechaISO)) {
          fechaISO = '${fechaISO}T00:00:00';
        }

        resultado.add({'monto': monto, 'categoria': cat, 'fechaISO': fechaISO});
      }
    }

    return resultado;
  }

  @override
  Widget build(BuildContext context) {
    const coral = Color(0xFFFF6464);

    return Dialog(
      backgroundColor: Colors.white.withOpacity(0.93),
      elevation: 12,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        width: 360,
        constraints: const BoxConstraints(maxWidth: 370),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: coral, size: 28),
                splashRadius: 26,
                onPressed: () => Navigator.pop(context),
                tooltip: "Cerrar",
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Registrar gasto',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 23,
                color: Colors.black,
                letterSpacing: 1.1,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 11),
            Text(
              'Describe tus gastos con lenguaje natural',
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              enabled: !_cargando,
              minLines: 2,
              maxLines: 4,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Ej: Gasté 7 en pan ayer',
                filled: true,
                fillColor: const Color(0xFFF9F9F9),
                prefixIcon: const Icon(Icons.edit, color: coral),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                      color: coral.withOpacity(0.13), width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: coral, width: 2.2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _cargando ? null : _analizarGasto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: coral,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 2,
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                icon: _cargando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 3, color: Colors.white),
                      )
                    : const Icon(Icons.add, size: 22),
                label: Text(_cargando ? '' : 'Guardar gasto'),
              ),
            ),
            if (_resultado.isNotEmpty) ...[
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: coral.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  _resultado,
                  style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5),
                  textAlign: TextAlign.left,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
