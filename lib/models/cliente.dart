class Cliente {
  final int? id;

  /// 'consumidor' (consumidor final) o 'empresa'.
  final String tipoCliente;

  /// Consumidor final: nombre y apellido. Empresa: nombre de la empresa.
  final String nombreApellido;

  /// Solo consumidor final.
  final String? cedula;

  /// Solo empresa.
  final String? rnc;

  /// Persona de contacto (solo empresa).
  final String? contacto;

  final String? telefono;
  final String? direccion;
  final String? notas;

  const Cliente({
    this.id,
    this.tipoCliente = 'consumidor',
    required this.nombreApellido,
    this.cedula,
    this.rnc,
    this.contacto,
    this.telefono,
    this.direccion,
    this.notas,
  });

  bool get esEmpresa => tipoCliente == 'empresa';

  factory Cliente.fromMap(Map<String, Object?> m) => Cliente(
        id: m['id'] as int?,
        tipoCliente: (m['tipo_cliente'] as String?) ?? 'consumidor',
        nombreApellido: m['nombre_apellido'] as String,
        cedula: m['cedula'] as String?,
        rnc: m['rnc'] as String?,
        contacto: m['contacto'] as String?,
        telefono: m['telefono'] as String?,
        direccion: m['direccion'] as String?,
        notas: m['notas'] as String?,
      );

  /// Sin 'id': la base lo genera sola al insertar.
  Map<String, Object?> toMap() => {
        'tipo_cliente': tipoCliente,
        'nombre_apellido': nombreApellido,
        'cedula': cedula,
        'rnc': rnc,
        'contacto': contacto,
        'telefono': telefono,
        'direccion': direccion,
        'notas': notas,
      };
}
