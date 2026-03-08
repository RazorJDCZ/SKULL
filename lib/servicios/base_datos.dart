import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/material.dart';

import '../modelos/gasto.dart';
import '../modelos/suscripcion.dart';

class BaseDatos {
  static Database? _db;

  static int encodeIcon(IconData icon) => icon.codePoint;
  static IconData decodeIcon(int codePoint) =>
      IconData(codePoint, fontFamily: 'MaterialIcons');

  // Útil para asegurar tablas en arranque o si vienes de versiones antiguas
  static Future<void> asegurarTablas(Database db) async {
  
    await db.execute('''
      CREATE TABLE IF NOT EXISTS gastos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        monto REAL NOT NULL,
        categoria TEXT NOT NULL,
        fecha TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_gastos_fecha ON gastos(fecha)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_gastos_categoria ON gastos(categoria)');

    // suscripciones (nueva)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suscripciones (
        nombre TEXT PRIMARY KEY,
        monto REAL NOT NULL,
        icono INTEGER NOT NULL,
        diaPago INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_suscripciones_dia ON suscripciones(diaPago)');
  }

  static Future<Database> _inicializarDB() async {
    final path = join(await getDatabasesPath(), 'gastos.db');
    return openDatabase(
      path,
      version: 4, // ⬅️ subimos versión para forzar migración
      onCreate: (db, version) async => asegurarTablas(db),
      onOpen: (db) async => asegurarTablas(db), // ⬅️ garantiza tablas SIEMPRE
      onUpgrade: (db, oldV, newV) async {
        // Migraciones idempotentes
        if (oldV < 2) {
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_gastos_fecha ON gastos(fecha)');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_gastos_categoria ON gastos(categoria)');
        }
        if (oldV < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS suscripciones (
              nombre TEXT PRIMARY KEY,
              monto REAL NOT NULL,
              icono INTEGER NOT NULL,
              diaPago INTEGER NOT NULL
            )
          ''');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_suscripciones_dia ON suscripciones(diaPago)');
        }
        if (oldV < 4) {
          // Reaseguramos todo por si venías de una BD “rara”
          await asegurarTablas(db);
        }
      },
    );
  }

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _inicializarDB();
    return _db!;
  }

  // ---------- GASTOS ----------
  static Future<int> insertarGasto(Gasto gasto) async {
    final database = await db;
    return database.insert(
      'gastos',
      gasto.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Gasto>> obtenerGastos() async {
    final database = await db;
    final maps = await database.query('gastos', orderBy: 'fecha DESC');
    return maps.map((m) => Gasto.fromMap(m)).toList();
  }

  static Future<List<Gasto>> obtenerGastosDelMes(int year, int month) async {
    final database = await db;
    final prefijo =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final maps = await database.query(
      'gastos',
      where: "substr(fecha, 1, 7) = ?",
      whereArgs: [prefijo],
      orderBy: 'fecha DESC',
    );
    return maps.map((m) => Gasto.fromMap(m)).toList();
  }

  static Future<void> eliminarGasto(int id) async {
    final database = await db;
    await database.delete('gastos', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> actualizarGasto(Gasto gasto) async {
    if (gasto.id == null) {
      throw ArgumentError('No se puede actualizar un gasto sin ID.');
    }
    final database = await db;
    await database.update(
      'gastos',
      gasto.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [gasto.id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<double> totalDelDia(DateTime d) async {
    final database = await db;
    final iso = d.toIso8601String().substring(0, 10);
    final res = await database.rawQuery(
      "SELECT SUM(monto) as total FROM gastos WHERE substr(fecha,1,10)=?",
      [iso],
    );
    final v = res.first['total'];
    return (v is num) ? v.toDouble() : 0.0;
  }

  static Future<double> totalDelMes(DateTime d) async {
    final database = await db;
    final prefijo =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
    final res = await database.rawQuery(
      "SELECT SUM(monto) as total FROM gastos WHERE substr(fecha,1,7)=?",
      [prefijo],
    );
    final v = res.first['total'];
    return (v is num) ? v.toDouble() : 0.0;
  }

  static Future<void> eliminarTodo() async {
    final database = await db;
    await database.delete('gastos');
  }

  // ---------- SUSCRIPCIONES ----------
  static Map<String, Object?> _suscripcionToMap(Suscripcion s) => {
        'nombre': s.nombre,
        'monto': s.monto,
        'icono': encodeIcon(s.icono),
        'diaPago': s.diaPago,
      };

  static Suscripcion _suscripcionFromMap(Map<String, Object?> m) => Suscripcion(
        nombre: (m['nombre'] as String),
        monto: (m['monto'] as num).toDouble(),
        icono: decodeIcon((m['icono'] as num).toInt()),
        diaPago: (m['diaPago'] as num).toInt(),
      );

  static Future<void> insertarSuscripcion(Suscripcion s) async {
    final database = await db;
    await database.insert(
      'suscripciones',
      _suscripcionToMap(s),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Suscripcion>> obtenerSuscripciones() async {
    final database = await db;
    final maps = await database.query(
      'suscripciones',
      orderBy: 'nombre COLLATE NOCASE ASC',
    );
    return maps.map(_suscripcionFromMap).toList();
  }

  static Future<void> actualizarSuscripcion(
      String nombreAnterior, Suscripcion nueva) async {
    final database = await db;
    await database.update(
      'suscripciones',
      _suscripcionToMap(nueva),
      where: 'nombre = ?',
      whereArgs: [nombreAnterior],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> actualizarIconoSuscripcion(
      String nombre, IconData icono) async {
    final database = await db;
    await database.update(
      'suscripciones',
      {'icono': encodeIcon(icono)},
      where: 'nombre = ?',
      whereArgs: [nombre],
    );
  }

  static Future<void> eliminarSuscripcion(String nombre) async {
    final database = await db;
    await database.delete('suscripciones',
        where: 'nombre = ?', whereArgs: [nombre]);
  }

  static Future<void> cerrar() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}

