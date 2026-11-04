import '../data/base_datos.dart';
import 'modelos.dart';

/// Listas administrables: marcas, modelos y categorías (extienden BaseDatos).
extension CatalogosDb on BaseDatos {
  // ------------------------------------------------------------ Categorías

  /// [cantidad] = en cuántos productos se usa.
  Future<List<ItemCatalogo>> listarCategorias() async {
    final d = await db;
    final filas = await d.rawQuery(
      'SELECT c.id, c.nombre, '
      '(SELECT COUNT(*) FROM producto p WHERE p.categoria_id = c.id) AS cantidad '
      'FROM categoria c ORDER BY c.nombre COLLATE NOCASE',
    );
    return filas.map(ItemCatalogo.fromMap).toList();
  }

  /// Crea la categoría; si ya existe (sin importar mayúsculas) devuelve la existente.
  Future<int> crearCategoria(String nombre) async {
    final d = await db;
    final n = nombre.trim();
    final existente = await d.query('categoria',
        columns: ['id'], where: 'nombre = ?', whereArgs: [n], limit: 1);
    if (existente.isNotEmpty) return existente.first['id'] as int;
    return d.insert('categoria', {'nombre': n});
  }

  Future<void> renombrarCategoria(int id, String nombre) async {
    final d = await db;
    await d.update('categoria', {'nombre': nombre.trim()},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> productosConCategoria(int id) async {
    final d = await db;
    final r = await d.rawQuery(
        'SELECT COUNT(*) AS n FROM producto WHERE categoria_id = ?', [id]);
    return (r.first['n'] as int?) ?? 0;
  }

  Future<void> eliminarCategoria(int id) async {
    final d = await db;
    await d.delete('categoria', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------ Marcas

  /// [cantidad] = cuántos modelos tiene la marca.
  Future<List<ItemCatalogo>> listarMarcas() async {
    final d = await db;
    final filas = await d.rawQuery(
      'SELECT m.id, m.nombre, '
      '(SELECT COUNT(*) FROM modelo mo WHERE mo.marca_id = m.id) AS cantidad '
      'FROM marca m ORDER BY m.nombre COLLATE NOCASE',
    );
    return filas.map(ItemCatalogo.fromMap).toList();
  }

  /// Crea la marca; si ya existe (sin importar mayúsculas) devuelve la existente.
  Future<int> crearMarca(String nombre) async {
    final d = await db;
    final n = nombre.trim();
    final existente = await d.query('marca',
        columns: ['id'], where: 'nombre = ?', whereArgs: [n], limit: 1);
    if (existente.isNotEmpty) return existente.first['id'] as int;
    return d.insert('marca', {'nombre': n});
  }

  Future<void> renombrarMarca(int id, String nombre) async {
    final d = await db;
    await d.update('marca', {'nombre': nombre.trim()},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> productosConMarca(int id) async {
    final d = await db;
    final r = await d.rawQuery(
        'SELECT COUNT(*) AS n FROM producto WHERE marca_id = ?', [id]);
    return (r.first['n'] as int?) ?? 0;
  }

  /// Borra también los modelos de la marca (el formulario avisa antes).
  Future<void> eliminarMarca(int id) async {
    final d = await db;
    await d.delete('marca', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------ Modelos

  /// [cantidad] = en cuántos productos se usa el modelo.
  Future<List<ItemCatalogo>> listarModelosDe(int marcaId) async {
    final d = await db;
    final filas = await d.rawQuery(
      'SELECT mo.id, mo.nombre, '
      '(SELECT COUNT(*) FROM producto p WHERE p.modelo_id = mo.id) AS cantidad '
      'FROM modelo mo WHERE mo.marca_id = ? '
      'ORDER BY mo.nombre COLLATE NOCASE',
      [marcaId],
    );
    return filas.map(ItemCatalogo.fromMap).toList();
  }

  /// Crea el modelo en esa marca; si ya existe devuelve el existente.
  Future<int> crearModelo(int marcaId, String nombre) async {
    final d = await db;
    final n = nombre.trim();
    final existente = await d.query('modelo',
        columns: ['id'],
        where: 'marca_id = ? AND nombre = ?',
        whereArgs: [marcaId, n],
        limit: 1);
    if (existente.isNotEmpty) return existente.first['id'] as int;
    return d.insert('modelo', {'marca_id': marcaId, 'nombre': n});
  }

  Future<void> renombrarModelo(int id, String nombre) async {
    final d = await db;
    await d.update('modelo', {'nombre': nombre.trim()},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> productosConModelo(int id) async {
    final d = await db;
    final r = await d.rawQuery(
        'SELECT COUNT(*) AS n FROM producto WHERE modelo_id = ?', [id]);
    return (r.first['n'] as int?) ?? 0;
  }

  Future<void> eliminarModelo(int id) async {
    final d = await db;
    await d.delete('modelo', where: 'id = ?', whereArgs: [id]);
  }
}
