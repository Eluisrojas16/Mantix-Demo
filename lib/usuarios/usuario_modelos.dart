import 'package:flutter/foundation.dart';

/// Roles predefinidos que sirven como plantilla de permisos.
const rolesPredefinidos = <String, String>{
  'admin': 'Administrador (Acceso total)',
  'cobrador': 'Cobrador / Finanzas',
  'facturador': 'Facturador (Ventas y Clientes)',
  'inventario': 'Almacén / Inventario',
  'personalizado': 'Personalizado (Cotejo manual)',
};

/// Bancos e instituciones de pago en República Dominicana
const bancosDominicanos = [
  'Efectivo',
  'Banco Popular Dominicano',
  'Banco de Reservas (Banreservas)',
  'Banco BHD',
  'Asociación Popular (APAP)',
  'Banco Santa Cruz',
  'Scotiabank',
  'Otro banco / Transferencia',
];

/// Modelo de Usuario con permisos granulares (cotejos por área).
class Usuario {
  final int? id;
  final String nombre;
  final String usuario;
  final String clave;
  final String rolBase;

  // Permisos individuales por módulo (cotejos)
  final bool permisoProximos;
  final bool permisoClientes;
  final bool permisoInventario;
  final bool permisoVentas;
  final bool permisoCobranzas;
  final bool permisoReportes;
  final bool permisoAdmin;

  final bool activo;
  final String? creadoEn;

  const Usuario({
    this.id,
    required this.nombre,
    required this.usuario,
    required this.clave,
    this.rolBase = 'personalizado',
    this.permisoProximos = true,
    this.permisoClientes = true,
    this.permisoInventario = false,
    this.permisoVentas = false,
    this.permisoCobranzas = false,
    this.permisoReportes = false,
    this.permisoAdmin = false,
    this.activo = true,
    this.creadoEn,
  });

  bool get esAdmin => permisoAdmin;

  Usuario copyWith({
    int? id,
    String? nombre,
    String? usuario,
    String? clave,
    String? rolBase,
    bool? permisoProximos,
    bool? permisoClientes,
    bool? permisoInventario,
    bool? permisoVentas,
    bool? permisoCobranzas,
    bool? permisoReportes,
    bool? permisoAdmin,
    bool? activo,
  }) {
    return Usuario(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      usuario: usuario ?? this.usuario,
      clave: clave ?? this.clave,
      rolBase: rolBase ?? this.rolBase,
      permisoProximos: permisoProximos ?? this.permisoProximos,
      permisoClientes: permisoClientes ?? this.permisoClientes,
      permisoInventario: permisoInventario ?? this.permisoInventario,
      permisoVentas: permisoVentas ?? this.permisoVentas,
      permisoCobranzas: permisoCobranzas ?? this.permisoCobranzas,
      permisoReportes: permisoReportes ?? this.permisoReportes,
      permisoAdmin: permisoAdmin ?? this.permisoAdmin,
      activo: activo ?? this.activo,
      creadoEn: creadoEn,
    );
  }

  factory Usuario.fromMap(Map<String, Object?> m) => Usuario(
        id: m['id'] as int?,
        nombre: m['nombre'] as String,
        usuario: m['usuario'] as String,
        clave: m['clave'] as String,
        rolBase: (m['rol_base'] as String?) ?? 'personalizado',
        permisoProximos: (m['permiso_proximos'] as int? ?? 1) == 1,
        permisoClientes: (m['permiso_clientes'] as int? ?? 1) == 1,
        permisoInventario: (m['permiso_inventario'] as int? ?? 0) == 1,
        permisoVentas: (m['permiso_ventas'] as int? ?? 0) == 1,
        permisoCobranzas: (m['permiso_cobranzas'] as int? ?? 0) == 1,
        permisoReportes: (m['permiso_reportes'] as int? ?? 0) == 1,
        permisoAdmin: (m['permiso_admin'] as int? ?? 0) == 1,
        activo: (m['activo'] as int? ?? 1) == 1,
        creadoEn: m['creado_en'] as String?,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'nombre': nombre,
        'usuario': usuario,
        'clave': clave,
        'rol_base': rolBase,
        'permiso_proximos': permisoProximos ? 1 : 0,
        'permiso_clientes': permisoClientes ? 1 : 0,
        'permiso_inventario': permisoInventario ? 1 : 0,
        'permiso_ventas': permisoVentas ? 1 : 0,
        'permiso_cobranzas': permisoCobranzas ? 1 : 0,
        'permiso_reportes': permisoReportes ? 1 : 0,
        'permiso_admin': permisoAdmin ? 1 : 0,
        'activo': activo ? 1 : 0,
      };
}

/// Registro histórico de un abono recibido (para auditoría y cuadre de caja).
class PagoAbono {
  final int? id;
  final int facturaId;
  final String fechaHora;
  final String fecha;
  final double montoCapital;
  final double moraCobrada;
  final double montoTotal;
  final String metodoPago;
  final String? referencia;
  final String usuarioNombre;
  final String? notas;

  const PagoAbono({
    this.id,
    required this.facturaId,
    required this.fechaHora,
    required this.fecha,
    required this.montoCapital,
    this.moraCobrada = 0,
    required this.montoTotal,
    this.metodoPago = 'Efectivo',
    this.referencia,
    required this.usuarioNombre,
    this.notas,
  });

  factory PagoAbono.fromMap(Map<String, Object?> m) => PagoAbono(
        id: m['id'] as int?,
        facturaId: m['factura_id'] as int,
        fechaHora: m['fecha_hora'] as String,
        fecha: m['fecha'] as String,
        montoCapital: (m['monto_capital'] as num).toDouble(),
        moraCobrada: (m['mora_cobrada'] as num?)?.toDouble() ?? 0,
        montoTotal: (m['monto_total'] as num).toDouble(),
        metodoPago: (m['metodo_pago'] as String?) ?? 'Efectivo',
        referencia: m['referencia'] as String?,
        usuarioNombre: (m['usuario_nombre'] as String?) ?? 'Admin',
        notas: m['notas'] as String?,
      );
}

/// Estado global de sesión del usuario en la aplicación.
class Sesion extends ChangeNotifier {
  Sesion._();
  static final Sesion instancia = Sesion._();

  Usuario? _actual;

  Usuario? get actual => _actual;
  bool get autenticado => _actual != null;

  String get nombreUsuario => _actual?.nombre ?? 'Administrador';

  void iniciar(Usuario usuario) {
    _actual = usuario;
    notifyListeners();
  }

  void cerrar() {
    _actual = null;
    notifyListeners();
  }
}
