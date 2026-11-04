import '../models/cliente.dart';
import 'base_datos.dart';

/// Búsquedas que cruzan clientes y aires (extienden BaseDatos).
extension BuscarDb on BaseDatos {
  /// Un renglón por cliente, con su cantidad de aires activos.
  /// Filtra por nombre, cédula, teléfono o por el lugar (posición), marca
  /// o modelo de cualquiera de sus aires.
  Future<List<Map<String, Object?>>> buscarClientes([String filtro = '']) async {
    final d = await db;
    final f = filtro.trim();
    const base = 'SELECT c.id AS cliente_id, c.nombre_apellido, c.cedula, '
        'c.telefono, '
        '(SELECT COUNT(*) FROM aire a '
        'WHERE a.cliente_id = c.id AND a.activo = 1) AS num_aires '
        'FROM cliente c';
    const orden = ' ORDER BY c.nombre_apellido COLLATE NOCASE';
    if (f.isEmpty) {
      return d.rawQuery('$base$orden');
    }
    final like = '%$f%';
    return d.rawQuery(
      '$base WHERE c.nombre_apellido LIKE ? OR c.cedula LIKE ? '
      'OR c.rnc LIKE ? '
      'OR c.telefono LIKE ? '
      'OR EXISTS (SELECT 1 FROM aire a WHERE a.cliente_id = c.id '
      'AND a.activo = 1 '
      'AND (a.posicion LIKE ? OR a.marca LIKE ? OR a.modelo LIKE ?))$orden',
      [like, like, like, like, like, like, like],
    );
  }

  /// El cliente creado más recientemente (para abrirlo justo después de crearlo).
  Future<Cliente?> ultimoCliente() async {
    final d = await db;
    final filas = await d.query('cliente', orderBy: 'id DESC', limit: 1);
    return filas.isEmpty ? null : Cliente.fromMap(filas.first);
  }
}
