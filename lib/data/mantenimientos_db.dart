import '../models/aire.dart';
import '../models/mantenimiento.dart';
import 'base_datos.dart';

/// Consultas de mantenimientos (extienden BaseDatos).
extension MantenimientosDb on BaseDatos {
  Future<Aire?> obtenerAire(int id) async {
    final d = await db;
    final filas = await d.query(
      'aire',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return filas.isEmpty ? null : Aire.fromMap(filas.first);
  }

  Future<List<Mantenimiento>> listarMantenimientos(int aireId) async {
    final d = await db;
    final filas = await d.query(
      'mantenimiento',
      where: 'aire_id = ?',
      whereArgs: [aireId],
      orderBy: 'fecha DESC, id DESC',
    );
    return filas.map(Mantenimiento.fromMap).toList();
  }

  /// Inserta si no tiene id, actualiza si lo tiene. Devuelve el id.
  Future<int> guardarMantenimiento(Mantenimiento m) async {
    final d = await db;
    if (m.id == null) {
      return d.insert('mantenimiento', m.toMap());
    }
    await d.update('mantenimiento', m.toMap(), where: 'id = ?', whereArgs: [m.id]);
    return m.id!;
  }

  Future<void> eliminarMantenimiento(int id) async {
    final d = await db;
    await d.delete('mantenimiento', where: 'id = ?', whereArgs: [id]);
  }

  /// Último y siguiente mantenimiento de un aire (calculados por la vista).
  /// Devuelve null si el aire está inactivo.
  Future<Map<String, Object?>?> proximoDeAire(int aireId) async {
    final d = await db;
    final filas = await d.rawQuery(
      'SELECT * FROM v_proximos_mantenimientos WHERE aire_id = ?',
      [aireId],
    );
    return filas.isEmpty ? null : filas.first;
  }
}
