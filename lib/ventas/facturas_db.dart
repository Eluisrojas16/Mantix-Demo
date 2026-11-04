import '../data/base_datos.dart';
import '../inventario/seriales_db.dart';
import '../usuarios/usuario_modelos.dart';
import '../utils/dinero.dart';
import '../utils/fechas.dart';
import '../utils/numeros.dart';
import 'factura_modelos.dart';
import 'modelos.dart';

/// Consultas y operaciones de facturas (extienden BaseDatos).
extension FacturasDb on BaseDatos {
  Future<List<Factura>> listarFacturas({
    String filtro = '',
    String? estado,
    String? condicion,
  }) async {
    final d = await db;
    final condiciones = <String>[];
    final args = <Object?>[];
    if (estado != null) {
      condiciones.add('estado = ?');
      args.add(estado);
    }
    if (condicion != null) {
      condiciones.add('condicion_venta = ?');
      args.add(condicion);
    }
    final f = filtro.trim();
    if (f.isNotEmpty) {
      condiciones.add(
        "(cliente_nombre LIKE ? OR printf('FAC-%04d', id) LIKE ? OR ncf LIKE ?)",
      );
      args.addAll(['%$f%', '%$f%', '%$f%']);
    }
    final where =
        condiciones.isEmpty ? '' : 'WHERE ${condiciones.join(' AND ')}';
    final filas = await d.rawQuery(
      'SELECT * FROM factura $where ORDER BY id DESC',
      args,
    );
    return filas.map(Factura.fromMap).toList();
  }

  Future<Factura?> obtenerFactura(int id) async {
    final d = await db;
    final filas =
        await d.query('factura', where: 'id = ?', whereArgs: [id], limit: 1);
    return filas.isEmpty ? null : Factura.fromMap(filas.first);
  }

  /// La factura (la más reciente) que salió de una cotización, si hay.
  Future<Factura?> facturaDeCotizacion(int cotizacionId) async {
    final d = await db;
    final filas = await d.query(
      'factura',
      where: 'cotizacion_id = ?',
      whereArgs: [cotizacionId],
      orderBy: 'id DESC',
      limit: 1,
    );
    return filas.isEmpty ? null : Factura.fromMap(filas.first);
  }

  /// Líneas de la factura, con los seriales que se despacharon en cada una.
  Future<List<LineaVenta>> listarLineasFactura(int facturaId) async {
    final d = await db;
    final filas = await d.query(
      'factura_linea',
      where: 'factura_id = ?',
      whereArgs: [facturaId],
      orderBy: 'orden, id',
    );
    final lineas = <LineaVenta>[];
    for (final f in filas) {
      final base = LineaVenta.fromMap(f);
      final seriales = await d.rawQuery(
        'SELECT u.id, u.serial FROM factura_linea_serial fs '
        'JOIN unidad u ON u.id = fs.unidad_id '
        'WHERE fs.factura_linea_id = ? ORDER BY u.serial COLLATE NOCASE',
        [f['id']],
      );
      lineas.add(
        seriales.isEmpty
            ? base
            : base.conSeriales(
                [for (final s in seriales) s['id'] as int],
                [for (final s in seriales) s['serial'] as String],
              ),
      );
    }
    return lineas;
  }

  /// Lista las cuotas de una factura determinada ordenadas por número.
  Future<List<Cuota>> listarCuotasFactura(int facturaId) async {
    final d = await db;
    final filas = await d.query(
      'cuota',
      where: 'factura_id = ?',
      whereArgs: [facturaId],
      orderBy: 'numero ASC',
    );
    return filas.map(Cuota.fromMap).toList();
  }

  /// Emite la factura: guarda la factura y sus líneas, descuenta el inventario
  /// (con el serial exacto en los productos que lo llevan) y genera el plan de
  /// cuotas si es a crédito. Todo en una sola transacción: o se hace todo,
  /// o no se hace nada. Lanza StateError con el motivo si algo no cuadra.
  Future<int> emitirFactura(Factura f, List<LineaVenta> lineas) async {
    if (lineas.isEmpty) {
      throw StateError('La factura no tiene líneas.');
    }
    final d = await db;
    final t = Totales.de(lineas);
    final esCredito = f.condicionVenta == 'credito';

    // Cálculo financiero
    final inicial = esCredito ? f.inicial.clamp(0, t.total).toDouble() : 0.0;
    final capital = (t.total - inicial).clamp(0, double.infinity).toDouble();
    final interes = esCredito && f.interesPct > 0
        ? redondear2(capital * (f.interesPct / 100))
        : 0.0;
    final totalFinanciado = esCredito ? redondear2(capital + interes) : t.total;
    final saldoPendiente = esCredito
        ? totalFinanciado
        : (f.estado == 'pagada' ? 0.0 : t.total);
    final cuotasCant = esCredito ? f.cantidadCuotas.clamp(1, 120) : 1;

    return d.transaction((txn) async {
      // 0) La cotización debe poder facturarse.
      if (f.cotizacionId != null) {
        final q = await txn.query(
          'cotizacion',
          columns: ['estado'],
          where: 'id = ?',
          whereArgs: [f.cotizacionId],
          limit: 1,
        );
        if (q.isEmpty) throw StateError('La cotización ya no existe.');
        final estado = q.first['estado'];
        if (estado == 'facturada') {
          throw StateError('Esta cotización ya fue facturada.');
        }
        if (estado == 'rechazada') {
          throw StateError('Una cotización rechazada no se puede facturar.');
        }
      }

      // 1) Revisar el inventario ANTES de guardar nada.
      final necesario = <int, double>{};
      final info = <int, Map<String, Object?>>{};
      for (final l in lineas) {
        final pid = l.productoId;
        if (pid == null) continue;
        final filas = await txn.rawQuery(
          'SELECT p.nombre, p.clase, p.maneja_serial, '
          'COALESCE(s.stock, 0) AS stock '
          'FROM producto p LEFT JOIN v_stock s ON s.producto_id = p.id '
          'WHERE p.id = ?',
          [pid],
        );
        if (filas.isEmpty) continue;
        final p = filas.first;
        info[pid] = p;
        if (p['clase'] == 'miscelaneo') continue;
        if ((p['maneja_serial'] as int) == 1) {
          if (l.cantidad != l.cantidad.roundToDouble() ||
              l.unidadIds.length != l.cantidad.round()) {
            throw StateError(
              '"${p['nombre']}": elige ${l.cantidad.round()} número(s) de serie.',
            );
          }
        } else {
          necesario[pid] = (necesario[pid] ?? 0) + l.cantidad;
        }
      }
      for (final e in necesario.entries) {
        final stock = (info[e.key]!['stock'] as num).toDouble();
        if (e.value > stock + 0.000001) {
          throw StateError(
            'No hay suficiente existencia de "${info[e.key]!['nombre']}" '
            '(hay ${formatoCantidad(stock)}, necesitas ${formatoCantidad(e.value)}).',
          );
        }
      }

      // 2) Guardar la factura.
      final id = await txn.insert('factura', <String, Object?>{
        'cliente_id': f.clienteId,
        'cotizacion_id': f.cotizacionId,
        'fecha': f.fecha,
        'ncf': f.ncf,
        'estado': f.estado,
        'forma_pago': f.formaPago,
        'fecha_pago': f.fechaPago,
        'cliente_nombre': f.clienteNombre,
        'cliente_documento': f.clienteDocumento,
        'cliente_telefono': f.clienteTelefono,
        'cliente_direccion': f.clienteDireccion,
        'notas': f.notas,
        'subtotal': t.subtotal,
        'itbis': t.itbis,
        'total': t.total,
        'condicion_venta': f.condicionVenta,
        'inicial': inicial,
        'interes_pct': f.interesPct,
        'frecuencia_pago': f.frecuenciaPago,
        'cantidad_cuotas': cuotasCant,
        'mora_pct': f.moraPct,
        'total_financiado': totalFinanciado,
        'saldo_pendiente': saldoPendiente,
      });
      final numero = numeroFactura(id);

      // 3) Generar cuotas si es a crédito o si es al contado pendiente
      final fechaBase = deIso(f.fecha) ?? hoySinHora();
      if (esCredito) {
        final cuotaBase = redondear2(totalFinanciado / cuotasCant);
        var acumulado = 0.0;
        for (var i = 1; i <= cuotasCant; i++) {
          final esUltima = i == cuotasCant;
          final montoCuota = esUltima
              ? redondear2(totalFinanciado - acumulado)
              : cuotaBase;
          acumulado += montoCuota;
          final vto = calcularVencimientoCuota(fechaBase, f.frecuenciaPago, i);
          await txn.insert('cuota', <String, Object?>{
            'factura_id': id,
            'numero': i,
            'fecha_vencimiento': aIso(vto),
            'monto': montoCuota,
            'estado': 'pendiente',
            'monto_pagado': 0,
            'mora_cobrada': 0,
          });
        }
      } else if (f.estado != 'pagada') {
        // Al contado pero pendiente de cobro: se registra 1 cuota única
        await txn.insert('cuota', <String, Object?>{
          'factura_id': id,
          'numero': 1,
          'fecha_vencimiento': f.fecha,
          'monto': t.total,
          'estado': 'pendiente',
          'monto_pagado': 0,
          'mora_cobrada': 0,
        });
      }

      // 4) Líneas y salida de inventario.
      for (var i = 0; i < lineas.length; i++) {
        final l = lineas[i];
        final lineaId = await txn.insert('factura_linea', <String, Object?>{
          ...l.toMap(),
          'factura_id': id,
          'orden': i,
        });
        final pid = l.productoId;
        final p = pid == null ? null : info[pid];
        if (pid == null || p == null || p['clase'] == 'miscelaneo') continue;
        if ((p['maneja_serial'] as int) == 1) {
          await registrarSalidaSerialesEn(
            txn,
            productoId: pid,
            fecha: f.fecha,
            unidadIds: l.unidadIds,
            origen: 'factura',
            referencia: numero,
          );
          for (final u in l.unidadIds) {
            await txn.insert('factura_linea_serial', <String, Object?>{
              'factura_linea_id': lineaId,
              'unidad_id': u,
            });
          }
        } else {
          await txn.insert('movimiento_inventario', <String, Object?>{
            'producto_id': pid,
            'fecha': f.fecha,
            'tipo': 'salida',
            'cantidad': l.cantidad,
            'origen': 'factura',
            'referencia': numero,
            'usuario_id': Sesion.instancia.actual?.id,
            'usuario_nombre': Sesion.instancia.actual?.nombre ?? 'Admin',
          });
        }
      }

      // 5) La cotización queda facturada (y ya no se puede modificar).
      if (f.cotizacionId != null) {
        await txn.update(
          'cotizacion',
          {'estado': 'facturada'},
          where: 'id = ?',
          whereArgs: [f.cotizacionId],
        );
      }
      return id;
    });
  }

  /// Registra un abono libre a una factura a crédito en CASCADA.
  /// Si el abono supera la cuota actual, salda esa cuota y el excedente
  /// se abona automáticamente a la(s) siguiente(s) cuota(s).
  Future<void> registrarAbonoFactura({
    required int facturaId,
    required double montoAbono,
    required double moraCobrada,
    String metodoPago = 'Efectivo',
    String? referencia,
    String usuarioNombre = 'Admin',
    String? notas,
  }) async {
    if (montoAbono <= 0) {
      throw StateError('El monto a abonar debe ser mayor a cero.');
    }
    final d = await db;
    await d.transaction((txn) async {
      final fMap = await txn.query(
        'factura',
        where: 'id = ?',
        whereArgs: [facturaId],
        limit: 1,
      );
      if (fMap.isEmpty) throw StateError('La factura no existe.');
      final f = Factura.fromMap(fMap.first);
      if (f.anulada) throw StateError('La factura está anulada.');
      if (f.saldada) throw StateError('La factura ya está totalmente saldada.');

      final cFilas = await txn.query(
        'cuota',
        where: 'factura_id = ?',
        whereArgs: [facturaId],
        orderBy: 'numero ASC',
      );
      final cuotas = cFilas.map(Cuota.fromMap).toList();
      final hoy = aIso(hoySinHora());

      var restante = montoAbono;

      for (final c in cuotas) {
        if (restante <= 0.000001) break;
        final saldoCuota =
            (c.monto - c.montoPagado).clamp(0, double.infinity).toDouble();
        if (saldoCuota <= 0.000001) continue; // ya estaba cubierta

        if (restante >= saldoCuota - 0.000001) {
          // Se completa la cuota al 100%
          await txn.update(
            'cuota',
            {
              'estado': 'pagada',
              'fecha_pago': hoy,
              'monto_pagado': c.monto,
              'notas': notas,
            },
            where: 'id = ?',
            whereArgs: [c.id],
          );
          restante -= saldoCuota;
        } else {
          // Abono parcial a esta cuota
          final nuevoPagado =
              redondear2((c.montoPagado + restante).toDouble());
          await txn.update(
            'cuota',
            {
              'estado': 'pendiente',
              'fecha_pago': hoy,
              'monto_pagado': nuevoPagado,
              'notas': notas,
            },
            where: 'id = ?',
            whereArgs: [c.id],
          );
          restante = 0;
        }
      }

      // Si hubo cobro de mora, registrarlo en la cuota vencida
      if (moraCobrada > 0) {
        final cuotaVencida = cuotas.firstWhere(
          (c) =>
              !c.pagada &&
              (diasHasta(c.fechaVencimiento) ?? 0) < 0,
          orElse: () => cuotas.first,
        );
        await txn.rawUpdate(
          'UPDATE cuota SET mora_cobrada = mora_cobrada + ? WHERE id = ?',
          [moraCobrada, cuotaVencida.id],
        );
      }

      // Reducir saldo de la factura por el capital efectivamente amortizado
      final capitalAmortizado = montoAbono - restante;
      await txn.rawUpdate(
        'UPDATE factura SET saldo_pendiente = MAX(0, saldo_pendiente - ?) WHERE id = ?',
        [capitalAmortizado, facturaId],
      );

      // Registrar la transacción en el historial de abonos (para cuadre y auditoría bancaria)
      await txn.insert('pago_abono', {
        'factura_id': facturaId,
        'fecha': hoy,
        'monto_capital': capitalAmortizado,
        'mora_cobrada': moraCobrada,
        'monto_total': capitalAmortizado + moraCobrada,
        'metodo_pago': metodoPago,
        'referencia': referencia,
        'usuario_nombre': usuarioNombre,
        'notas': notas,
      });

      // Si no queda saldo en la factura, marcarla como pagada
      final fActual = await txn.query(
        'factura',
        where: 'id = ?',
        whereArgs: [facturaId],
        limit: 1,
      );
      final saldoFinal =
          (fActual.first['saldo_pendiente'] as num?)?.toDouble() ?? 0.0;
      if (saldoFinal <= 0.0001) {
        await txn.update(
          'factura',
          {'estado': 'pagada', 'fecha_pago': hoy, 'saldo_pendiente': 0},
          where: 'id = ?',
          whereArgs: [facturaId],
        );
        await txn.update(
          'cuota',
          {'estado': 'pagada', 'fecha_pago': hoy},
          where: 'factura_id = ?',
          whereArgs: [facturaId],
        );
      }
    });
  }

  /// Cobra el saldo exacto de una cuota determinada (delegando al abono en cascada).
  Future<void> cobrarCuota({
    required int cuotaId,
    required double moraCobrada,
    String? notas,
  }) async {
    final d = await db;
    final fila = await d.query('cuota',
        where: 'id = ?', whereArgs: [cuotaId], limit: 1);
    if (fila.isEmpty) throw StateError('La cuota no existe.');
    final c = Cuota.fromMap(fila.first);
    await registrarAbonoFactura(
      facturaId: c.facturaId,
      montoAbono: c.saldo,
      moraCobrada: moraCobrada,
      notas: notas,
    );
  }

  /// Marca como pagada una factura al contado directamente.
  Future<void> marcarFacturaPagada(int id, [String? formaPago]) async {
    final d = await db;
    final hoy = aIso(hoySinHora());
    await d.transaction((txn) async {
      final n = await txn.update(
        'factura',
        {
          'estado': 'pagada',
          'forma_pago': formaPago,
          'fecha_pago': hoy,
          'saldo_pendiente': 0,
        },
        where: "id = ? AND estado <> 'anulada'",
        whereArgs: [id],
      );
      if (n == 0) throw StateError('No se pudo marcar como pagada.');
      await txn.update(
        'cuota',
        {
          'estado': 'pagada',
          'fecha_pago': hoy,
          'monto_pagado': 0,
        },
        where: 'factura_id = ?',
        whereArgs: [id],
      );
    });
  }

  /// Asigna o corrige el NCF. Falla si ya está en otra factura (UNIQUE).
  Future<void> asignarNcf(int id, String? ncf) async {
    final d = await db;
    final n = await d.update(
      'factura',
      {'ncf': (ncf == null || ncf.trim().isEmpty) ? null : ncf.trim()},
      where: "id = ? AND estado <> 'anulada'",
      whereArgs: [id],
    );
    if (n == 0) {
      throw StateError('No se puede cambiar el NCF de una factura anulada.');
    }
  }

  /// Anula la factura, elimina sus cuotas pendientes y devuelve los productos al inventario.
  Future<void> anularFactura(int id, String motivo) async {
    final d = await db;
    await d.transaction((txn) async {
      final f = await txn.query('factura',
          where: 'id = ?', whereArgs: [id], limit: 1);
      if (f.isEmpty) throw StateError('La factura no existe.');
      if (f.first['estado'] == 'anulada') {
        throw StateError('La factura ya está anulada.');
      }
      final numero = numeroFactura(id);
      final hoy = aIso(hoySinHora());
      final salidas = await txn.query(
        'movimiento_inventario',
        where: "origen = 'factura' AND referencia = ? AND tipo = 'salida'",
        whereArgs: [numero],
      );
      for (final m in salidas) {
        final entradaId =
            await txn.insert('movimiento_inventario', <String, Object?>{
          'producto_id': m['producto_id'],
          'fecha': hoy,
          'tipo': 'entrada',
          'cantidad': m['cantidad'],
          'origen': 'anulacion',
          'referencia': numero,
          'usuario_id': Sesion.instancia.actual?.id,
          'usuario_nombre': Sesion.instancia.actual?.nombre ?? 'Admin',
        });
        await txn.rawUpdate(
          "UPDATE unidad SET estado = 'en_stock', movimiento_salida_id = NULL, "
          "movimiento_entrada_id = ? WHERE movimiento_salida_id = ?",
          [entradaId, m['id']],
        );
      }
      // Eliminar las cuotas pendientes para que no queden en cobranzas
      await txn.delete('cuota', where: 'factura_id = ?', whereArgs: [id]);

      await txn.update(
        'factura',
        {
          'estado': 'anulada',
          'motivo_anulacion': motivo,
          'saldo_pendiente': 0,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }
}
