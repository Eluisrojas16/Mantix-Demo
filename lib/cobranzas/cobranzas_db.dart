import '../data/base_datos.dart';
import '../utils/fechas.dart';
import '../ventas/factura_modelos.dart';
import 'cobranzas_modelos.dart';

extension CobranzasDb on BaseDatos {
  /// Lista los créditos activos o saldados agrupados por factura.
  Future<List<CreditoCobranza>> listarCreditosCobranza({
    String filtro = '',
    String filtroEstado = 'activos', // 'activos', 'vencidos', 'saldados'
  }) async {
    final d = await db;
    final condiciones = <String>[
      "f.condicion_venta = 'credito'",
      "f.estado <> 'anulada'",
    ];
    final args = <Object?>[];

    if (filtroEstado == 'saldados') {
      condiciones.add("(f.saldo_pendiente <= 0.0001 OR f.estado = 'pagada')");
    } else {
      condiciones.add("(f.saldo_pendiente > 0.0001 AND f.estado <> 'pagada')");
    }

    final f = filtro.trim();
    if (f.isNotEmpty) {
      condiciones.add(
        "(f.cliente_nombre LIKE ? OR f.cliente_telefono LIKE ? OR printf('FAC-%04d', f.id) LIKE ?)",
      );
      args.addAll(['%$f%', '%$f%', '%$f%']);
    }

    final where = 'WHERE ${condiciones.join(' AND ')}';
    final sql = 'SELECT * FROM factura f $where ORDER BY f.id DESC';
    final filasFacturas = await d.rawQuery(sql, args);

    final lista = <CreditoCobranza>[];
    for (final m in filasFacturas) {
      final fac = Factura.fromMap(m);
      final cFilas = await d.query(
        'cuota',
        where: 'factura_id = ?',
        whereArgs: [fac.id],
        orderBy: 'numero ASC',
      );
      final cuotas = cFilas.map(Cuota.fromMap).toList();
      lista.add(CreditoCobranza(factura: fac, cuotas: cuotas));
    }

    // Si el filtro es "vencidos", dejar solo los que tienen al menos una cuota en mora
    if (filtroEstado == 'vencidos') {
      return lista.where((c) => c.tieneVencidas).toList()
        ..sort((a, b) {
          final da = a.diasHastaProximoVencimiento ?? 9999;
          final db = b.diasHastaProximoVencimiento ?? 9999;
          return da.compareTo(db);
        });
    }

    // Ordenar activos por fecha de próximo pago más cercana (las vencidas primero)
    if (filtroEstado == 'activos') {
      lista.sort((a, b) {
        final da = a.diasHastaProximoVencimiento ?? 9999;
        final db = b.diasHastaProximoVencimiento ?? 9999;
        return da.compareTo(db);
      });
    }

    return lista;
  }

  /// Métricas globales del módulo de cobranzas.
  Future<ResumenCobranza> obtenerResumenCobranza() async {
    final d = await db;
    final hoy = aIso(hoySinHora());
    final mesActual = hoy.substring(0, 7); // AAAA-MM

    // Total por cobrar (saldo de créditos activos)
    final rPendiente = await d.rawQuery('''
      SELECT COALESCE(SUM(saldo_pendiente), 0) AS total
      FROM factura
      WHERE condicion_venta = 'credito' 
        AND estado <> 'anulada' 
        AND saldo_pendiente > 0
    ''');
    final totalPorCobrar =
        (rPendiente.first['total'] as num?)?.toDouble() ?? 0.0;

    // Total vencido en mora y cantidad de créditos atrasados
    final rVencido = await d.rawQuery('''
      SELECT 
        COALESCE(SUM(c.monto - c.monto_pagado), 0) AS total,
        COUNT(DISTINCT f.id) AS cantidad
      FROM cuota c
      JOIN factura f ON f.id = c.factura_id
      WHERE f.condicion_venta = 'credito'
        AND f.estado <> 'anulada'
        AND f.saldo_pendiente > 0
        AND c.estado <> 'pagada'
        AND (c.monto - c.monto_pagado) > 0.0001
        AND c.fecha_vencimiento < ?
    ''', [hoy]);
    final totalVencido = (rVencido.first['total'] as num?)?.toDouble() ?? 0.0;
    final cantidadVencidos =
        (rVencido.first['cantidad'] as num?)?.toInt() ?? 0;

    // Cobrado en el mes en curso (monto pagado de cuotas en este mes)
    final rCobrado = await d.rawQuery('''
      SELECT COALESCE(SUM(c.monto_pagado), 0) AS total
      FROM cuota c
      JOIN factura f ON f.id = c.factura_id
      WHERE f.condicion_venta = 'credito'
        AND f.estado <> 'anulada'
        AND c.fecha_pago LIKE ?
    ''', ['$mesActual%']);
    final cobradoMes = (rCobrado.first['total'] as num?)?.toDouble() ?? 0.0;

    return ResumenCobranza(
      totalPorCobrar: totalPorCobrar,
      totalVencido: totalVencido,
      cantidadCreditosVencidos: cantidadVencidos,
      cobradoEsteMes: cobradoMes,
    );
  }
}
