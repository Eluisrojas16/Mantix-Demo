import '../data/base_datos.dart';
import '../usuarios/usuario_modelos.dart';
import 'modelos.dart';

/// Consultas de productos y movimientos (extienden BaseDatos).
extension InventarioDb on BaseDatos {
  static const _selectProducto =
      'SELECT p.id, p.codigo, p.nombre, p.clase, p.categoria_id, p.marca_id, '
      'p.modelo_id, p.numero_parte, p.descripcion, p.unidad, p.costo, '
      'p.precio_venta, p.stock_minimo, p.activo, p.maneja_serial, '
      'c.nombre AS categoria_nombre, m.nombre AS marca_nombre, '
      'mo.nombre AS modelo_nombre, COALESCE(s.stock, 0) AS stock '
      'FROM producto p '
      'LEFT JOIN categoria c ON c.id = p.categoria_id '
      'LEFT JOIN marca m ON m.id = p.marca_id '
      'LEFT JOIN modelo mo ON mo.id = p.modelo_id '
      'LEFT JOIN v_stock s ON s.producto_id = p.id';

  ProductoConStock _aProductoConStock(Map<String, Object?> m) =>
      ProductoConStock(Producto.fromMap(m), (m['stock'] as num).toDouble());

  Future<List<ProductoConStock>> listarProductos({
    String filtro = '',
    int? categoriaId,
    String? clase,
    bool soloActivos = true,
  }) async {
    final d = await db;
    final condiciones = <String>[];
    final args = <Object?>[];
    if (soloActivos) condiciones.add('p.activo = 1');
    if (categoriaId != null) {
      condiciones.add('p.categoria_id = ?');
      args.add(categoriaId);
    }
    if (clase != null) {
      condiciones.add('p.clase = ?');
      args.add(clase);
    }
    final f = filtro.trim();
    if (f.isNotEmpty) {
      condiciones.add(
        '(p.nombre LIKE ? OR p.codigo LIKE ? OR m.nombre LIKE ? '
        'OR mo.nombre LIKE ? OR p.numero_parte LIKE ? OR c.nombre LIKE ?)',
      );
      args.addAll(List.filled(6, '%$f%'));
    }
    final where =
        condiciones.isEmpty ? '' : 'WHERE ${condiciones.join(' AND ')}';
    final filas = await d.rawQuery(
      '$_selectProducto $where ORDER BY p.nombre COLLATE NOCASE',
      args,
    );
    return filas.map(_aProductoConStock).toList();
  }

  Future<ProductoConStock?> obtenerProducto(int id) async {
    final d = await db;
    final filas = await d.rawQuery('$_selectProducto WHERE p.id = ?', [id]);
    return filas.isEmpty ? null : _aProductoConStock(filas.first);
  }

  /// Inserta si no tiene id, actualiza si lo tiene. Devuelve el id.
  Future<int> guardarProducto(Producto p) async {
    final d = await db;
    if (p.id == null) {
      return d.insert('producto', p.toMap());
    }
    await d.update('producto', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
    return p.id!;
  }

  Future<List<Movimiento>> listarMovimientos(int productoId) async {
    final d = await db;
    final filas = await d.query(
      'movimiento_inventario',
      where: 'producto_id = ?',
      whereArgs: [productoId],
      orderBy: 'fecha DESC, id DESC',
    );
    return filas.map(Movimiento.fromMap).toList();
  }

  Future<int> registrarMovimiento(Movimiento m) async {
    final d = await db;
    // Se estampa al usuario de la sesión por encima de lo que venga en el mapa.
    final u = Sesion.instancia.actual;
    return d.insert('movimiento_inventario', <String, Object?>{
      ...m.toMap(),
      'usuario_id': u?.id,
      'usuario_nombre': u?.nombre ?? 'Admin',
    });
  }

  Future<void> eliminarMovimiento(int id) async {
    final d = await db;
    await d.delete('movimiento_inventario', where: 'id = ?', whereArgs: [id]);
  }
}
