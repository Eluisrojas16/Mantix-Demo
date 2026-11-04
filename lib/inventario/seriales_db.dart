import 'package:sqflite/sqflite.dart';

import '../data/base_datos.dart';
import '../usuarios/usuario_modelos.dart';
import 'modelos.dart';

/// Registra la salida de unidades con serial dentro de una transacción (o base) ya
/// abierta. La usan las salidas de almacén y, más adelante, las facturas, para que la
/// factura y la salida del serial se guarden juntas o no se guarde ninguna.
Future<int> registrarSalidaSerialesEn(
  DatabaseExecutor ex, {
  required int productoId,
  required String fecha,
  required List<int> unidadIds,
  required String origen,
  String? referencia,
  String? nota,
}) async {
  if (unidadIds.isEmpty) {
    throw StateError('No se eligió ningún número de serie.');
  }
  final marcas = List.filled(unidadIds.length, '?').join(',');
  final r = await ex.rawQuery(
    "SELECT COUNT(*) AS n FROM unidad "
    "WHERE producto_id = ? AND estado = 'en_stock' AND id IN ($marcas)",
    [productoId, ...unidadIds],
  );
  if (((r.first['n'] as int?) ?? 0) != unidadIds.length) {
    throw StateError('Alguno de los seriales ya no está en existencia.');
  }
  final movimientoId = await ex.insert('movimiento_inventario', {
    'producto_id': productoId,
    'fecha': fecha,
    'tipo': 'salida',
    'cantidad': unidadIds.length.toDouble(),
    'origen': origen,
    'referencia': referencia,
    'nota': nota,
    'usuario_id': Sesion.instancia.actual?.id,
    'usuario_nombre': Sesion.instancia.actual?.nombre ?? 'Admin',
  });
  await ex.rawUpdate(
    "UPDATE unidad SET estado = 'despachado', movimiento_salida_id = ? "
    "WHERE id IN ($marcas)",
    [movimientoId, ...unidadIds],
  );
  return movimientoId;
}

/// Control por número de serie (extiende BaseDatos).
extension SerialesDb on BaseDatos {
  Future<List<Unidad>> listarUnidades(int productoId) async {
    final d = await db;
    final filas = await d.rawQuery(
      'SELECT u.id, u.producto_id, u.serial, u.estado, '
      'me.fecha AS fecha_entrada, ms.fecha AS fecha_salida, '
      'ms.origen AS origen_salida, ms.referencia AS referencia_salida '
      'FROM unidad u '
      'LEFT JOIN movimiento_inventario me ON me.id = u.movimiento_entrada_id '
      'LEFT JOIN movimiento_inventario ms ON ms.id = u.movimiento_salida_id '
      'WHERE u.producto_id = ? '
      'ORDER BY u.estado, u.serial COLLATE NOCASE',
      [productoId],
    );
    return filas.map(Unidad.fromMap).toList();
  }

  /// De la lista dada, los seriales que ya existen en el sistema (de cualquier producto).
  Future<List<String>> serialesExistentes(List<String> seriales) async {
    final d = await db;
    final existentes = <String>[];
    for (var i = 0; i < seriales.length; i += 400) {
      final trozo = seriales.sublist(
        i,
        i + 400 > seriales.length ? seriales.length : i + 400,
      );
      final marcas = List.filled(trozo.length, '?').join(',');
      final filas = await d.rawQuery(
        'SELECT serial FROM unidad WHERE serial IN ($marcas)',
        trozo,
      );
      existentes.addAll([for (final f in filas) f['serial'] as String]);
    }
    return existentes;
  }

  /// Registra una entrada con sus números de serie. La cantidad de la entrada es
  /// la cantidad de seriales. Si algún serial ya existe, no se guarda nada y se
  /// lanza un StateError con el detalle. Con [reingresar] (una devolución) un serial
  /// que ya fue despachado de este mismo producto vuelve a quedar en existencia.
  Future<int> registrarEntradaSeriales({
    required int productoId,
    required String fecha,
    required List<String> seriales,
    double? costoUnitario,
    String origen = 'compra',
    String? referencia,
    String? nota,
    bool reingresar = false,
  }) async {
    if (seriales.isEmpty) {
      throw StateError('Escribe al menos un número de serie.');
    }
    final d = await db;
    return d.transaction((txn) async {
      // 1) Revisar todos antes de guardar cualquiera.
      final conflictos = <String>[];
      final reactivar = <String, int>{}; // serial -> id de la unidad despachada
      for (final s in seriales) {
        final f = await txn.query(
          'unidad',
          columns: ['id', 'producto_id', 'estado'],
          where: 'serial = ?',
          whereArgs: [s],
          limit: 1,
        );
        if (f.isEmpty) continue;
        final u = f.first;
        if (reingresar &&
            u['producto_id'] == productoId &&
            u['estado'] == 'despachado') {
          reactivar[s] = u['id'] as int;
        } else {
          conflictos.add(s);
        }
      }
      if (conflictos.isNotEmpty) {
        final lista = conflictos.take(5).join(', ');
        final resto = conflictos.length > 5 ? ' y ${conflictos.length - 5} más' : '';
        throw StateError('Estos seriales ya están registrados: $lista$resto.');
      }

      // 2) Guardar la entrada y sus unidades.
      final movimientoId = await txn.insert('movimiento_inventario', {
        'producto_id': productoId,
        'fecha': fecha,
        'tipo': 'entrada',
        'cantidad': seriales.length.toDouble(),
        'costo_unitario': costoUnitario,
        'origen': origen,
        'referencia': referencia,
        'nota': nota,
        'usuario_id': Sesion.instancia.actual?.id,
        'usuario_nombre': Sesion.instancia.actual?.nombre ?? 'Admin',
      });
      for (final s in seriales) {
        final idExistente = reactivar[s];
        if (idExistente != null) {
          await txn.update(
            'unidad',
            {
              'estado': 'en_stock',
              'movimiento_entrada_id': movimientoId,
              'movimiento_salida_id': null,
            },
            where: 'id = ?',
            whereArgs: [idExistente],
          );
        } else {
          await txn.insert('unidad', {
            'producto_id': productoId,
            'serial': s,
            'estado': 'en_stock',
            'movimiento_entrada_id': movimientoId,
          });
        }
      }
      return movimientoId;
    });
  }

  /// Salida de almacén eligiendo los seriales exactos que se despachan.
  Future<int> registrarSalidaSeriales({
    required int productoId,
    required String fecha,
    required List<int> unidadIds,
    required String origen,
    String? referencia,
    String? nota,
  }) async {
    final d = await db;
    return d.transaction(
      (txn) => registrarSalidaSerialesEn(
        txn,
        productoId: productoId,
        fecha: fecha,
        unidadIds: unidadIds,
        origen: origen,
        referencia: referencia,
        nota: nota,
      ),
    );
  }

  /// Corrige un serial mal escrito. Solo si la unidad sigue en existencia.
  Future<void> cambiarSerial(int unidadId, String nuevo) async {
    final d = await db;
    final n = await d.update(
      'unidad',
      {'serial': nuevo.trim()},
      where: "id = ? AND estado = 'en_stock'",
      whereArgs: [unidadId],
    );
    if (n == 0) {
      throw StateError('Solo se puede corregir un serial que está en existencia.');
    }
  }

  /// ¿El producto ya tiene movimientos? (si los tiene, no se puede cambiar cómo se controla)
  Future<bool> tieneMovimientos(int productoId) async {
    final d = await db;
    final r = await d.rawQuery(
      'SELECT COUNT(*) AS n FROM movimiento_inventario WHERE producto_id = ?',
      [productoId],
    );
    return ((r.first['n'] as int?) ?? 0) > 0;
  }
}
