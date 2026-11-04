class Aire {
  final int? id;
  final int clienteId;
  final String? posicion;
  final String? marca;
  final String? modelo;
  final String? tipo;
  final int? btu;
  final String? serial;
  final int periodicidadMeses;
  final bool activo;

  const Aire({
    this.id,
    required this.clienteId,
    this.posicion,
    this.marca,
    this.modelo,
    this.tipo,
    this.btu,
    this.serial,
    this.periodicidadMeses = 6,
    this.activo = true,
  });

  factory Aire.fromMap(Map<String, Object?> m) => Aire(
        id: m['id'] as int?,
        clienteId: m['cliente_id'] as int,
        posicion: m['posicion'] as String?,
        marca: m['marca'] as String?,
        modelo: m['modelo'] as String?,
        tipo: m['tipo'] as String?,
        btu: m['btu'] as int?,
        serial: m['serial'] as String?,
        periodicidadMeses: (m['periodicidad_meses'] as int?) ?? 6,
        activo: ((m['activo'] as int?) ?? 1) == 1,
      );

  /// Sin 'id': la base lo genera sola al insertar.
  Map<String, Object?> toMap() => {
        'cliente_id': clienteId,
        'posicion': posicion,
        'marca': marca,
        'modelo': modelo,
        'tipo': tipo,
        'btu': btu,
        'serial': serial,
        'periodicidad_meses': periodicidadMeses,
        'activo': activo ? 1 : 0,
      };
}
