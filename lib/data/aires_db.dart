import 'package:sqflite/sqflite.dart';

import '../models/aire.dart';
import '../models/cliente.dart';
import 'base_datos.dart';

/// Consultas de aires acondicionados (extienden BaseDatos).
extension AiresDb on BaseDatos {
  Future<Cliente?> obtenerCliente(int id) async {
    final d = await db;
    final filas = await d.query(
      'cliente',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return filas.isEmpty ? null : Cliente.fromMap(filas.first);
  }

  Future<List<Aire>> listarAires(int clienteId) async {
    final d = await db;
    final filas = await d.query(
      'aire',
      where: 'cliente_id = ?',
      whereArgs: [clienteId],
      orderBy: 'activo DESC, posicion COLLATE NOCASE',
    );
    return filas.map(Aire.fromMap).toList();
  }

  /// Inserta si no tiene id, actualiza si lo tiene. Devuelve el id.
  Future<int> guardarAire(Aire a) async {
    final d = await db;
    if (a.id == null) {
      return d.insert('aire', a.toMap());
    }
    await d.update('aire', a.toMap(), where: 'id = ?', whereArgs: [a.id]);
    return a.id!;
  }

  Future<int> contarMantenimientos(int aireId) async {
    final d = await db;
    final r = await d.rawQuery(
      'SELECT COUNT(*) FROM mantenimiento WHERE aire_id = ?',
      [aireId],
    );
    return Sqflite.firstIntValue(r) ?? 0;
  }

  /// Ojo: por el esquema, borra también su historial de mantenimientos.
  Future<void> eliminarAire(int id) async {
    final d = await db;
    await d.delete('aire', where: 'id = ?', whereArgs: [id]);
  }
}
