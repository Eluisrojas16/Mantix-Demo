import '../data/base_datos.dart';
import '../utils/fechas.dart';
import 'modelos.dart';
import 'ventas_db.dart';

/// Operaciones adicionales de cotizaciones (extienden BaseDatos).
extension CotizacionesExtraDb on BaseDatos {
  /// Crea un borrador nuevo con los mismos datos y líneas, con la fecha de hoy.
  /// Devuelve el id de la copia.
  Future<int> duplicarCotizacion(int id) async {
    final original = await obtenerCotizacion(id);
    if (original == null) throw StateError('La cotización ya no existe.');
    final lineas = await listarLineasCotizacion(id);
    final negocio = await obtenerNegocio();
    final hoy = hoySinHora();
    final copia = Cotizacion(
      clienteId: original.clienteId,
      fecha: aIso(hoy),
      vigenciaHasta: aIso(
        DateTime(hoy.year, hoy.month, hoy.day + negocio.vigenciaDias),
      ),
      estado: 'borrador',
      notas: original.notas,
    );
    return guardarCotizacion(copia, lineas);
  }
}
