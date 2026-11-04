import 'dart:typed_data';

import '../utils/dinero.dart';
import '../utils/fechas.dart';

const estadosCotizacion = <String, String>{
  'borrador': 'Borrador',
  'enviada': 'Enviada',
  'aceptada': 'Aceptada',
  'rechazada': 'Rechazada',
  'facturada': 'Facturada',
};

/// Estados que se pueden elegir a mano ("facturada" la pone el sistema).
const estadosCotizacionEditables = ['borrador', 'enviada', 'aceptada', 'rechazada'];

/// 12 -> "COT-0012"
String numeroCotizacion(int id) => 'COT-${id.toString().padLeft(4, '0')}';

/// Datos del negocio que aparecen en cotizaciones y facturas.
class Negocio {
  final String nombre;
  final String? rnc;
  final String? direccion;
  final String? telefono;
  final String? correo;
  final double itbisPorcentaje;
  final int vigenciaDias;
  final String? condiciones;
  final Uint8List? logo;

  const Negocio({
    required this.nombre,
    this.rnc,
    this.direccion,
    this.telefono,
    this.correo,
    this.itbisPorcentaje = 18,
    this.vigenciaDias = 15,
    this.condiciones,
    this.logo,
  });

  factory Negocio.fromMap(Map<String, Object?> m) => Negocio(
        nombre: m['nombre'] as String,
        rnc: m['rnc'] as String?,
        direccion: m['direccion'] as String?,
        telefono: m['telefono'] as String?,
        correo: m['correo'] as String?,
        itbisPorcentaje: (m['itbis_porcentaje'] as num?)?.toDouble() ?? 18,
        vigenciaDias: (m['vigencia_dias'] as int?) ?? 15,
        condiciones: m['condiciones'] as String?,
        logo: m['logo'] as Uint8List?,
      );

  Map<String, Object?> toMap() => {
        'nombre': nombre,
        'rnc': rnc,
        'direccion': direccion,
        'telefono': telefono,
        'correo': correo,
        'itbis_porcentaje': itbisPorcentaje,
        'vigencia_dias': vigenciaDias,
        'condiciones': condiciones,
        'logo': logo,
      };
}

/// Una línea de cotización (y más adelante de factura): un artículo del
/// inventario o un concepto libre.
class LineaVenta {
  final int? id;
  final int? productoId; // vacío en conceptos libres
  final String descripcion;
  final double cantidad;
  final String unidad;
  final double precioUnitario;
  final double descuentoPct;
  final double itbisPct;

  /// Solo en facturas: los seriales (y sus ids) de las unidades que se despachan.
  final List<String> seriales;
  final List<int> unidadIds;

  const LineaVenta({
    this.id,
    this.productoId,
    required this.descripcion,
    this.cantidad = 1,
    this.unidad = 'unidad',
    this.precioUnitario = 0,
    this.descuentoPct = 0,
    this.itbisPct = 18,
    this.seriales = const [],
    this.unidadIds = const [],
  });

  /// Importe sin ITBIS, con el descuento aplicado.
  double get base =>
      redondear2(cantidad * precioUnitario * (1 - descuentoPct / 100));

  double get itbis => redondear2(base * itbisPct / 100);

  double get total => redondear2(base + itbis);

  /// Copia de la línea con los seriales (y los ids de sus unidades) indicados.
  LineaVenta conSeriales(List<int> ids, List<String> nombres) => LineaVenta(
        id: id,
        productoId: productoId,
        descripcion: descripcion,
        cantidad: cantidad,
        unidad: unidad,
        precioUnitario: precioUnitario,
        descuentoPct: descuentoPct,
        itbisPct: itbisPct,
        seriales: nombres,
        unidadIds: ids,
      );

  factory LineaVenta.fromMap(Map<String, Object?> m) => LineaVenta(
        id: m['id'] as int?,
        productoId: m['producto_id'] as int?,
        descripcion: m['descripcion'] as String,
        cantidad: (m['cantidad'] as num).toDouble(),
        unidad: (m['unidad'] as String?) ?? 'unidad',
        precioUnitario: (m['precio_unitario'] as num?)?.toDouble() ?? 0,
        descuentoPct: (m['descuento_pct'] as num?)?.toDouble() ?? 0,
        itbisPct: (m['itbis_pct'] as num?)?.toDouble() ?? 18,
      );

  /// Sin 'id' ni 'cotizacion_id': los pone quien guarda.
  Map<String, Object?> toMap() => {
        'producto_id': productoId,
        'descripcion': descripcion,
        'cantidad': cantidad,
        'unidad': unidad,
        'precio_unitario': precioUnitario,
        'descuento_pct': descuentoPct,
        'itbis_pct': itbisPct,
      };
}

/// Totales de un documento. Se calculan aquí y en ningún otro lugar.
class Totales {
  final double subtotal;
  final double itbis;
  const Totales(this.subtotal, this.itbis);

  double get total => redondear2(subtotal + itbis);

  factory Totales.de(List<LineaVenta> lineas) => Totales(
        redondear2(lineas.fold<double>(0, (suma, l) => suma + l.base)),
        redondear2(lineas.fold<double>(0, (suma, l) => suma + l.itbis)),
      );
}

class Cotizacion {
  final int? id;
  final int clienteId;
  final String? clienteNombre; // solo lectura
  final String fecha; // AAAA-MM-DD
  final String vigenciaHasta; // AAAA-MM-DD
  final String estado;
  final String? notas;
  final double subtotal;
  final double itbis;
  final double total;

  const Cotizacion({
    this.id,
    required this.clienteId,
    this.clienteNombre,
    required this.fecha,
    required this.vigenciaHasta,
    this.estado = 'borrador',
    this.notas,
    this.subtotal = 0,
    this.itbis = 0,
    this.total = 0,
  });

  String get numero => id == null ? 'Nueva' : numeroCotizacion(id!);

  /// Una cotización sin respuesta cuya vigencia ya pasó.
  bool get vencida {
    if (estado != 'borrador' && estado != 'enviada') return false;
    final d = diasHasta(vigenciaHasta);
    return d != null && d < 0;
  }

  factory Cotizacion.fromMap(Map<String, Object?> m) => Cotizacion(
        id: m['id'] as int?,
        clienteId: m['cliente_id'] as int,
        clienteNombre: m['cliente_nombre'] as String?,
        fecha: m['fecha'] as String,
        vigenciaHasta: m['vigencia_hasta'] as String,
        estado: (m['estado'] as String?) ?? 'borrador',
        notas: m['notas'] as String?,
        subtotal: (m['subtotal'] as num?)?.toDouble() ?? 0,
        itbis: (m['itbis'] as num?)?.toDouble() ?? 0,
        total: (m['total'] as num?)?.toDouble() ?? 0,
      );
}
