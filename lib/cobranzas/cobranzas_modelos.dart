import '../utils/fechas.dart';
import '../ventas/factura_modelos.dart';

/// Representa una Factura / Crédito activo en el módulo de Cobranzas,
/// agrupando todas sus cuotas y calculando en vivo la próxima cuota a vencer.
class CreditoCobranza {
  final Factura factura;
  final List<Cuota> cuotas;

  const CreditoCobranza({
    required this.factura,
    required this.cuotas,
  });

  String get clienteNombre => factura.clienteNombre;
  String? get clienteTelefono => factura.clienteTelefono;
  int get facturaId => factura.id!;
  String get numeroFacturaTexto => factura.numero;
  double get totalFinanciado => factura.totalFinanciado;
  double get saldoPendiente => factura.saldoPendiente;
  double get moraPct => factura.moraPct;
  int get cantidadCuotas => factura.cantidadCuotas;
  String get frecuenciaPago => factura.frecuenciaPago;

  double get totalPagadoCapital =>
      (totalFinanciado - saldoPendiente).clamp(0, double.infinity).toDouble();

  double get porcentajePagado => totalFinanciado > 0
      ? ((totalPagadoCapital / totalFinanciado) * 100).clamp(0, 100).toDouble()
      : 100.0;

  int get cuotasPagadasCount => cuotas.where((c) => c.pagada).length;

  /// La cuota activa más próxima que aún no está pagada en su totalidad
  Cuota? get proximaCuota {
    for (final c in cuotas) {
      if (!c.pagada && c.saldo > 0.0001) return c;
    }
    return null;
  }

  int? get diasHastaProximoVencimiento =>
      proximaCuota == null ? null : diasHasta(proximaCuota!.fechaVencimiento);

  bool get tieneVencidas {
    final hoy = aIso(hoySinHora());
    return cuotas.any(
      (c) => !c.pagada && c.saldo > 0.0001 && c.fechaVencimiento.compareTo(hoy) < 0,
    );
  }

  bool get proximaEstaVencida =>
      proximaCuota != null &&
      diasHastaProximoVencimiento != null &&
      diasHastaProximoVencimiento! < 0;

  bool get proximaVenceHoy =>
      proximaCuota != null &&
      diasHastaProximoVencimiento != null &&
      diasHastaProximoVencimiento == 0;

  double get moraSugerida {
    if (!proximaEstaVencida || moraPct <= 0 || proximaCuota == null) return 0.0;
    return double.parse(
      (proximaCuota!.saldo * (moraPct / 100)).toStringAsFixed(2),
    );
  }

  double get totalProximoPagoSugerido =>
      (proximaCuota?.saldo ?? 0.0) + moraSugerida;

  bool get saldada => factura.saldada || saldoPendiente <= 0.0001;
}

class ResumenCobranza {
  final double totalPorCobrar;
  final double totalVencido;
  final int cantidadCreditosVencidos;
  final double cobradoEsteMes;

  const ResumenCobranza({
    required this.totalPorCobrar,
    required this.totalVencido,
    required this.cantidadCreditosVencidos,
    required this.cobradoEsteMes,
  });
}
