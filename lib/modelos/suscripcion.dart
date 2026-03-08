import 'package:flutter/material.dart';

class Suscripcion {
  String nombre;
  double monto;
  IconData icono;
  /// Día de cobro: 1–28 habituales. Usa 31 para representar "último día del mes".
  int diaPago;

  Suscripcion({
    required this.nombre,
    required this.monto,
    required this.icono,
    required this.diaPago,
  }) : assert(diaPago >= 1 && diaPago <= 31,
          'diaPago debe estar entre 1 y 31 (31 = último día del mes)');

  
  bool get esUltimoDia => diaPago == 31;

  /// Crea una copia modificando solo los campos que pases.
  Suscripcion copyWith({
    String? nombre,
    double? monto,
    IconData? icono,
    int? diaPago,
  }) {
    return Suscripcion(
      nombre: nombre ?? this.nombre,
      monto: monto ?? this.monto,
      icono: icono ?? this.icono,
      diaPago: diaPago ?? this.diaPago,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'nombre': nombre,
      'monto': monto,
      'icono': icono.codePoint,
      'diaPago': diaPago,
    };
  }


  factory Suscripcion.fromMap(Map<String, Object?> map) {
    return Suscripcion(
      nombre: map['nombre'] as String,
      monto: (map['monto'] as num).toDouble(),
      icono: IconData((map['icono'] as num).toInt(), fontFamily: 'MaterialIcons'),
      diaPago: (map['diaPago'] as num).toInt(),
    );
    
  }

  @override
  String toString() =>
      'Suscripcion(nombre: $nombre, monto: $monto, icono: ${icono.codePoint}, diaPago: $diaPago)';

  @override
  bool operator ==(Object other) {
    return other is Suscripcion &&
        other.nombre == nombre &&
        other.monto == monto &&
        other.icono.codePoint == icono.codePoint &&
        other.diaPago == diaPago;
  }

  @override
  int get hashCode => Object.hash(nombre, monto, icono.codePoint, diaPago);
}
