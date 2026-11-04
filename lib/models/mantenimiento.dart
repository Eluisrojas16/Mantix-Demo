const tiposMantenimiento = <String, String>{
  'preventivo': 'Preventivo',
  'correctivo': 'Correctivo',
  'instalacion': 'Instalación',
};

const estadosMantenimiento = <String, String>{
  'realizado': 'Realizado',
  'programado': 'Programado',
  'cancelado': 'Cancelado',
};

class Mantenimiento {
  final int? id;
  final int aireId;
  final String fecha; // AAAA-MM-DD
  final String tipo;
  final String estado;
  final String? trabajoRealizado;
  final double? costo;
  final bool pagado;
  final String? tecnico;

  const Mantenimiento({
    this.id,
    required this.aireId,
    required this.fecha,
    this.tipo = 'preventivo',
    this.estado = 'realizado',
    this.trabajoRealizado,
    this.costo,
    this.pagado = false,
    this.tecnico,
  });

  factory Mantenimiento.fromMap(Map<String, Object?> m) => Mantenimiento(
        id: m['id'] as int?,
        aireId: m['aire_id'] as int,
        fecha: m['fecha'] as String,
        tipo: m['tipo'] as String,
        estado: m['estado'] as String,
        trabajoRealizado: m['trabajo_realizado'] as String?,
        costo: (m['costo'] as num?)?.toDouble(),
        pagado: ((m['pagado'] as int?) ?? 0) == 1,
        tecnico: m['tecnico'] as String?,
      );

  /// Sin 'id': la base lo genera sola al insertar.
  Map<String, Object?> toMap() => {
        'aire_id': aireId,
        'fecha': fecha,
        'tipo': tipo,
        'estado': estado,
        'trabajo_realizado': trabajoRealizado,
        'costo': costo,
        'pagado': pagado ? 1 : 0,
        'tecnico': tecnico,
      };
}
