class Gasto {
  int? id;           
  double monto;
  String categoria;
  DateTime fecha;

  Gasto({
    this.id,
    required this.monto,
    required this.categoria,
    required this.fecha,
  });

  // Para INSERT/UPDATE
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'monto': monto,
      'categoria': categoria,
      'fecha': fecha.toIso8601String(),
    };
  }

  factory Gasto.fromMap(Map<String, dynamic> map) {
    return Gasto(
      id: map['id'] as int?,
      monto: (map['monto'] as num).toDouble(),
      categoria: map['categoria'] as String,
      fecha: DateTime.parse(map['fecha'] as String),
    );
  }

  
  Gasto copyWith({
    int? id,
    double? monto,
    String? categoria,
    DateTime? fecha,
  }) {
    return Gasto(
      id: id ?? this.id,
      monto: monto ?? this.monto,
      categoria: categoria ?? this.categoria,
      fecha: fecha ?? this.fecha,
    );
  }


  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Gasto &&
          runtimeType == other.runtimeType &&
          id != null &&
          other.id == id;

  @override
  int get hashCode => id.hashCode;
}

