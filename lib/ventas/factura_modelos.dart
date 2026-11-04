const estadosFactura = <String, String>{
  'emitida': 'Emitida',
  'pagada': 'Pagada',
  'anulada': 'Anulada',
};

const condicionesVenta = <String, String>{
  'contado': 'Al Contado',
  'credito': 'A Crédito / Financiado',
};

const frecuenciasPago = <String, String>{
  'semanal': 'Semanal',
  'quincenal': 'Quincenal',
  'mensual': 'Mensual',
};

/// 12 -> "FAC-0012"
String numeroFactura(int id) => 'FAC-${id.toString().padLeft(4, '0')}';

/// Calcula la fecha de vencimiento según la frecuencia y el índice (1, 2, 3...)
DateTime calcularVencimientoCuota(DateTime base, String frecuencia, int indice) {
  switch (frecuencia) {
    case 'semanal':
      return base.add(Duration(days: 7 * indice));
    case 'quincenal':
      return base.add(Duration(days: 15 * indice));
    case 'mensual':
    default:
      final anio = base.year + (base.month + indice - 1) ~/ 12;
      final mes = (base.month + indice - 1) % 12 + 1;
      final ultimoDiaDelMes = DateTime(anio, mes + 1, 0).day;
      final dia = base.day > ultimoDiaDelMes ? ultimoDiaDelMes : base.day;
      return DateTime(anio, mes, dia);
  }
}

/// Una factura emitida. Guarda una copia de los datos del cliente al emitirse.
class Factura {
  final int? id;
  final int clienteId;
  final int? cotizacionId;
  final String fecha; // AAAA-MM-DD
  final String? ncf;
  final String estado; // emitida, pagada o anulada
  final String? formaPago;
  final String? fechaPago;
  final String clienteNombre;
  final String? clienteDocumento; // "RNC 1310..." o "Cédula 001..."
  final String? clienteTelefono;
  final String? clienteDireccion;
  final String? notas;
  final double subtotal;
  final double itbis;
  final double total;
  final String? motivoAnulacion;

  // Financiamiento y crédito
  final String condicionVenta; // 'contado' o 'credito'
  final double inicial;
  final double interesPct;
  final String frecuenciaPago; // 'semanal', 'quincenal', 'mensual'
  final int cantidadCuotas;
  final double moraPct;
  final double totalFinanciado;
  final double saldoPendiente;

  const Factura({
    this.id,
    required this.clienteId,
    this.cotizacionId,
    required this.fecha,
    this.ncf,
    this.estado = 'emitida',
    this.formaPago,
    this.fechaPago,
    required this.clienteNombre,
    this.clienteDocumento,
    this.clienteTelefono,
    this.clienteDireccion,
    this.notas,
    this.subtotal = 0,
    this.itbis = 0,
    this.total = 0,
    this.motivoAnulacion,
    this.condicionVenta = 'contado',
    this.inicial = 0,
    this.interesPct = 0,
    this.frecuenciaPago = 'mensual',
    this.cantidadCuotas = 1,
    this.moraPct = 0,
    this.totalFinanciado = 0,
    this.saldoPendiente = 0,
  });

  String get numero => id == null ? 'Nueva' : numeroFactura(id!);

  bool get anulada => estado == 'anulada';
  bool get esCredito => condicionVenta == 'credito';
  bool get saldada => estado == 'pagada' || (esCredito && saldoPendiente <= 0);

  factory Factura.fromMap(Map<String, Object?> m) => Factura(
        id: m['id'] as int?,
        clienteId: m['cliente_id'] as int,
        cotizacionId: m['cotizacion_id'] as int?,
        fecha: m['fecha'] as String,
        ncf: m['ncf'] as String?,
        estado: (m['estado'] as String?) ?? 'emitida',
        formaPago: m['forma_pago'] as String?,
        fechaPago: m['fecha_pago'] as String?,
        clienteNombre: m['cliente_nombre'] as String,
        clienteDocumento: m['cliente_documento'] as String?,
        clienteTelefono: m['cliente_telefono'] as String?,
        clienteDireccion: m['cliente_direccion'] as String?,
        notas: m['notas'] as String?,
        subtotal: (m['subtotal'] as num?)?.toDouble() ?? 0,
        itbis: (m['itbis'] as num?)?.toDouble() ?? 0,
        total: (m['total'] as num?)?.toDouble() ?? 0,
        motivoAnulacion: m['motivo_anulacion'] as String?,
        condicionVenta: (m['condicion_venta'] as String?) ?? 'contado',
        inicial: (m['inicial'] as num?)?.toDouble() ?? 0,
        interesPct: (m['interes_pct'] as num?)?.toDouble() ?? 0,
        frecuenciaPago: (m['frecuencia_pago'] as String?) ?? 'mensual',
        cantidadCuotas: (m['cantidad_cuotas'] as int?) ?? 1,
        moraPct: (m['mora_pct'] as num?)?.toDouble() ?? 0,
        totalFinanciado: (m['total_financiado'] as num?)?.toDouble() ??
            ((m['total'] as num?)?.toDouble() ?? 0),
        saldoPendiente: (m['saldo_pendiente'] as num?)?.toDouble() ?? 0,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'cliente_id': clienteId,
        'cotizacion_id': cotizacionId,
        'fecha': fecha,
        'ncf': ncf,
        'estado': estado,
        'forma_pago': formaPago,
        'fecha_pago': fechaPago,
        'cliente_nombre': clienteNombre,
        'cliente_documento': clienteDocumento,
        'cliente_telefono': clienteTelefono,
        'cliente_direccion': clienteDireccion,
        'notas': notas,
        'subtotal': subtotal,
        'itbis': itbis,
        'total': total,
        'motivo_anulacion': motivoAnulacion,
        'condicion_venta': condicionVenta,
        'inicial': inicial,
        'interes_pct': interesPct,
        'frecuencia_pago': frecuenciaPago,
        'cantidad_cuotas': cantidadCuotas,
        'mora_pct': moraPct,
        'total_financiado': totalFinanciado,
        'saldo_pendiente': saldoPendiente,
      };
}

/// Una cuota programada de pago para una factura a crédito.
class Cuota {
  final int? id;
  final int facturaId;
  final int numero;
  final String fechaVencimiento;
  final double monto;
  final String estado; // 'pendiente', 'pagada'
  final String? fechaPago;
  final double montoPagado;
  final double moraCobrada;
  final String? notas;

  const Cuota({
    this.id,
    required this.facturaId,
    required this.numero,
    required this.fechaVencimiento,
    required this.monto,
    this.estado = 'pendiente',
    this.fechaPago,
    this.montoPagado = 0,
    this.moraCobrada = 0,
    this.notas,
  });

  double get saldo =>
      (monto - montoPagado).clamp(0, double.infinity).toDouble();
  bool get pagada => estado == 'pagada' || saldo <= 0.0001;
  bool get esAbonoParcial => montoPagado > 0 && !pagada;

  factory Cuota.fromMap(Map<String, Object?> m) => Cuota(
        id: m['id'] as int?,
        facturaId: m['factura_id'] as int,
        numero: m['numero'] as int,
        fechaVencimiento: m['fecha_vencimiento'] as String,
        monto: (m['monto'] as num).toDouble(),
        estado: (m['estado'] as String?) ?? 'pendiente',
        fechaPago: m['fecha_pago'] as String?,
        montoPagado: (m['monto_pagado'] as num?)?.toDouble() ?? 0,
        moraCobrada: (m['mora_cobrada'] as num?)?.toDouble() ?? 0,
        notas: m['notas'] as String?,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'factura_id': facturaId,
        'numero': numero,
        'fecha_vencimiento': fechaVencimiento,
        'monto': monto,
        'estado': estado,
        'fecha_pago': fechaPago,
        'monto_pagado': montoPagado,
        'mora_cobrada': moraCobrada,
        'notas': notas,
      };
}
