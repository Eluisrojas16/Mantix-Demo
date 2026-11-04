/// Clases de producto. Producto y material controlan existencia; el misceláneo no.
const clasesProducto = <String, String>{
  'producto': 'Producto',
  'material': 'Material / repuesto',
  'miscelaneo': 'Misceláneo',
};

/// Nombres cortos para el selector del formulario.
const clasesProductoCortas = <String, String>{
  'producto': 'Producto',
  'material': 'Material',
  'miscelaneo': 'Misceláneo',
};

const ayudaClase = <String, String>{
  'producto': 'Equipos y artículos que se venden: se controla su existencia.',
  'material': 'Repuestos y materiales: se controla su existencia.',
  'miscelaneo':
      'No controla existencia. Sirve para facturar conceptos que no están en '
          'inventario, como mano de obra o instalación.',
};

const nombresTipoMovimiento = <String, String>{
  'entrada': 'Entrada',
  'salida': 'Salida',
  'ajuste': 'Ajuste',
};

/// Motivos que se pueden elegir al registrar un movimiento a mano.
const origenesMovimiento = <String, Map<String, String>>{
  'entrada': {
    'compra': 'Compra',
    'devolucion': 'Devolución de cliente',
    'otro': 'Otro',
  },
  'salida': {
    'uso_interno': 'Uso interno (instalación o servicio)',
    'merma': 'Merma o daño',
    'otro': 'Otro',
  },
  'ajuste': {
    'conteo': 'Conteo físico',
    'correccion': 'Corrección',
  },
};

/// Etiqueta legible de cualquier origen (incluye los que crea el sistema).
String etiquetaOrigen(String origen) {
  for (final motivos in origenesMovimiento.values) {
    final e = motivos[origen];
    if (e != null) return e;
  }
  switch (origen) {
    case 'inicial':
      return 'Existencia inicial';
    case 'factura':
      return 'Factura';
    case 'anulacion':
      return 'Anulación de factura';
    default:
      return origen;
  }
}

/// Un elemento de una lista administrable (marca, modelo o categoría).
/// [cantidad]: en marcas = cuántos modelos tiene; en modelos y categorías =
/// en cuántos productos se usa.
class ItemCatalogo {
  final int id;
  final String nombre;
  final int cantidad;
  const ItemCatalogo(this.id, this.nombre, [this.cantidad = 0]);

  factory ItemCatalogo.fromMap(Map<String, Object?> m) => ItemCatalogo(
        m['id'] as int,
        m['nombre'] as String,
        (m['cantidad'] as int?) ?? 0,
      );
}

class Producto {
  final int? id;
  final String? codigo;
  final String nombre;
  final String clase; // producto, material o miscelaneo
  final int? categoriaId;
  final int? marcaId;
  final int? modeloId;
  final String? categoriaNombre; // solo lectura (viene de las listas)
  final String? marcaNombre;
  final String? modeloNombre;
  final String? numeroParte;
  final String? descripcion;
  final String unidad;
  final double? costo;
  final double? precioVenta;
  final double stockMinimo;
  final bool activo;
  final bool manejaSerial;

  const Producto({
    this.id,
    this.codigo,
    required this.nombre,
    this.clase = 'producto',
    this.categoriaId,
    this.marcaId,
    this.modeloId,
    this.categoriaNombre,
    this.marcaNombre,
    this.modeloNombre,
    this.numeroParte,
    this.descripcion,
    this.unidad = 'unidad',
    this.costo,
    this.precioVenta,
    this.stockMinimo = 0,
    this.activo = true,
    this.manejaSerial = false,
  });

  /// Los misceláneos no manejan existencias.
  bool get controlaExistencia => clase != 'miscelaneo';

  /// Se controla unidad por unidad, con número de serie.
  bool get usaSerial => manejaSerial && controlaExistencia;

  factory Producto.fromMap(Map<String, Object?> m) => Producto(
        id: m['id'] as int?,
        codigo: m['codigo'] as String?,
        nombre: m['nombre'] as String,
        clase: (m['clase'] as String?) ?? 'producto',
        categoriaId: m['categoria_id'] as int?,
        marcaId: m['marca_id'] as int?,
        modeloId: m['modelo_id'] as int?,
        categoriaNombre: m['categoria_nombre'] as String?,
        marcaNombre: m['marca_nombre'] as String?,
        modeloNombre: m['modelo_nombre'] as String?,
        numeroParte: m['numero_parte'] as String?,
        descripcion: m['descripcion'] as String?,
        unidad: (m['unidad'] as String?) ?? 'unidad',
        costo: (m['costo'] as num?)?.toDouble(),
        precioVenta: (m['precio_venta'] as num?)?.toDouble(),
        stockMinimo: (m['stock_minimo'] as num?)?.toDouble() ?? 0,
        activo: ((m['activo'] as int?) ?? 1) == 1,
        manejaSerial: ((m['maneja_serial'] as int?) ?? 0) == 1,
      );

  /// Sin 'id' ni nombres: la base genera el id y los nombres salen de las listas.
  Map<String, Object?> toMap() => {
        'codigo': codigo,
        'nombre': nombre,
        'clase': clase,
        'categoria_id': categoriaId,
        'marca_id': marcaId,
        'modelo_id': modeloId,
        'numero_parte': numeroParte,
        'descripcion': descripcion,
        'unidad': unidad,
        'costo': costo,
        'precio_venta': precioVenta,
        'stock_minimo': stockMinimo,
        'activo': activo ? 1 : 0,
        'maneja_serial': manejaSerial ? 1 : 0,
      };
}

/// Un producto junto con su existencia actual (calculada por la vista v_stock).
class ProductoConStock {
  final Producto producto;
  final double stock;
  const ProductoConStock(this.producto, this.stock);

  /// 'sin_control', 'agotado', 'bajo' o 'ok'
  String get estado {
    if (!producto.controlaExistencia) return 'sin_control';
    if (stock <= 0) return 'agotado';
    if (producto.stockMinimo > 0 && stock <= producto.stockMinimo) {
      return 'bajo';
    }
    return 'ok';
  }
}

class Movimiento {
  final int? id;
  final int productoId;
  final String fecha; // AAAA-MM-DD
  final String tipo; // entrada, salida o ajuste
  final double cantidad;
  final double? costoUnitario;
  final String origen;
  final String? referencia;
  final String? nota;
  final int? usuarioId; // quién lo hizo (se llena al guardar)
  final String? usuarioNombre;

  const Movimiento({
    this.id,
    required this.productoId,
    required this.fecha,
    required this.tipo,
    required this.cantidad,
    this.costoUnitario,
    this.origen = 'manual',
    this.referencia,
    this.nota,
    this.usuarioId,
    this.usuarioNombre,
  });

  /// Cuánto suma (+) o resta (-) al stock.
  double get efecto => tipo == 'salida' ? -cantidad : cantidad;

  factory Movimiento.fromMap(Map<String, Object?> m) => Movimiento(
        id: m['id'] as int?,
        productoId: m['producto_id'] as int,
        fecha: m['fecha'] as String,
        tipo: m['tipo'] as String,
        cantidad: (m['cantidad'] as num).toDouble(),
        costoUnitario: (m['costo_unitario'] as num?)?.toDouble(),
        origen: (m['origen'] as String?) ?? 'manual',
        referencia: m['referencia'] as String?,
        nota: m['nota'] as String?,
        usuarioId: m['usuario_id'] as int?,
        usuarioNombre: m['usuario_nombre'] as String?,
      );

  Map<String, Object?> toMap() => {
        'producto_id': productoId,
        'fecha': fecha,
        'tipo': tipo,
        'cantidad': cantidad,
        'costo_unitario': costoUnitario,
        'origen': origen,
        'referencia': referencia,
        'nota': nota,
        'usuario_id': usuarioId,
        'usuario_nombre': usuarioNombre,
      };
}

/// Una unidad física con número de serie (ej. un aire acondicionado concreto).
class Unidad {
  final int id;
  final int productoId;
  final String serial;
  final String estado; // en_stock o despachado
  final String? fechaEntrada;
  final String? fechaSalida;
  final String? origenSalida;
  final String? referenciaSalida;

  const Unidad({
    required this.id,
    required this.productoId,
    required this.serial,
    required this.estado,
    this.fechaEntrada,
    this.fechaSalida,
    this.origenSalida,
    this.referenciaSalida,
  });

  bool get enStock => estado == 'en_stock';

  factory Unidad.fromMap(Map<String, Object?> m) => Unidad(
        id: m['id'] as int,
        productoId: m['producto_id'] as int,
        serial: m['serial'] as String,
        estado: m['estado'] as String,
        fechaEntrada: m['fecha_entrada'] as String?,
        fechaSalida: m['fecha_salida'] as String?,
        origenSalida: m['origen_salida'] as String?,
        referenciaSalida: m['referencia_salida'] as String?,
      );
}
