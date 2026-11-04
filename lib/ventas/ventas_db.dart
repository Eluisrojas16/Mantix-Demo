import '../data/base_datos.dart';
import 'modelos.dart';

/// Consultas de ventas (extienden BaseDatos).
extension VentasDb on BaseDatos {
  static const _selectCotizacion =
      'SELECT q.id, q.cliente_id, c.nombre_apellido AS cliente_nombre, '
      'q.fecha, q.vigencia_hasta, q.estado, q.notas, q.subtotal, q.itbis, '
      'q.total FROM cotizacion q JOIN cliente c ON c.id = q.cliente_id';

  // ------------------------------------------------------------ Negocio

  Future<Negocio> obtenerNegocio() async {
    final d = await db;
    final filas = await d.query('negocio', where: 'id = 1', limit: 1);
    return filas.isEmpty
        ? const Negocio(nombre: 'Mi negocio')
        : Negocio.fromMap(filas.first);
  }

  Future<void> guardarNegocio(Negocio n) async {
    final d = await db;
    final actualizadas = await d.update('negocio', n.toMap(), where: 'id = 1');
    if (actualizadas == 0) {
      await d.insert('negocio', {'id': 1, ...n.toMap()});
    }
  }

  // ------------------------------------------------------------ Cotizaciones

  Future<List<Cotizacion>> listarCotizaciones({
    String filtro = '',
    String? estado,
  }) async {
    final d = await db;
    final condiciones = <String>[];
    final args = <Object?>[];
    if (estado != null) {
      condiciones.add('q.estado = ?');
      args.add(estado);
    }
    final f = filtro.trim();
    if (f.isNotEmpty) {
      condiciones.add(
        "(c.nombre_apellido LIKE ? OR printf('COT-%04d', q.id) LIKE ?)",
      );
      args.addAll(['%$f%', '%$f%']);
    }
    final where =
        condiciones.isEmpty ? '' : 'WHERE ${condiciones.join(' AND ')}';
    final filas = await d.rawQuery(
      '$_selectCotizacion $where ORDER BY q.id DESC',
      args,
    );
    return filas.map(Cotizacion.fromMap).toList();
  }

  Future<Cotizacion?> obtenerCotizacion(int id) async {
    final d = await db;
    final filas = await d.rawQuery('$_selectCotizacion WHERE q.id = ?', [id]);
    return filas.isEmpty ? null : Cotizacion.fromMap(filas.first);
  }

  Future<List<LineaVenta>> listarLineasCotizacion(int cotizacionId) async {
    final d = await db;
    final filas = await d.query(
      'cotizacion_linea',
      where: 'cotizacion_id = ?',
      whereArgs: [cotizacionId],
      orderBy: 'orden, id',
    );
    return filas.map(LineaVenta.fromMap).toList();
  }

  /// Guarda la cotización y todas sus líneas de una sola vez. Los totales se
  /// calculan aquí a partir de las líneas. Devuelve el id.
  Future<int> guardarCotizacion(Cotizacion c, List<LineaVenta> lineas) async {
    final d = await db;
    final t = Totales.de(lineas);
    return d.transaction((txn) async {
      final valores = <String, Object?>{
        'cliente_id': c.clienteId,
        'fecha': c.fecha,
        'vigencia_hasta': c.vigenciaHasta,
        'estado': c.estado,
        'notas': c.notas,
        'subtotal': t.subtotal,
        'itbis': t.itbis,
        'total': t.total,
      };
      int id;
      if (c.id == null) {
        id = await txn.insert('cotizacion', valores);
      } else {
        id = c.id!;
        final actual = await txn.query('cotizacion',
            columns: ['estado'], where: 'id = ?', whereArgs: [id], limit: 1);
        if (actual.isNotEmpty && actual.first['estado'] == 'facturada') {
          throw StateError('Una cotización facturada no se puede modificar.');
        }
        await txn.update('cotizacion', valores,
            where: 'id = ?', whereArgs: [id]);
        await txn.delete('cotizacion_linea',
            where: 'cotizacion_id = ?', whereArgs: [id]);
      }
      for (var i = 0; i < lineas.length; i++) {
        await txn.insert('cotizacion_linea', {
          ...lineas[i].toMap(),
          'cotizacion_id': id,
          'orden': i,
        });
      }
      return id;
    });
  }

  Future<void> cambiarEstadoCotizacion(int id, String estado) async {
    final d = await db;
    await d.update('cotizacion', {'estado': estado},
        where: "id = ? AND estado <> 'facturada'", whereArgs: [id]);
  }

  Future<void> eliminarCotizacion(int id) async {
    final d = await db;
    await d.delete('cotizacion',
        where: "id = ? AND estado = 'borrador'", whereArgs: [id]);
  }
}
