import 'package:flutter/material.dart';

import '../data/base_datos.dart';
import '../inventario/dialogos.dart';
import '../utils/fechas.dart';
import '../utils/numeros.dart';
import '../usuarios/usuario_modelos.dart';
import '../ventas/factura_detalle_page.dart';
import '../ventas/facturas_db.dart';
import 'cobranzas_db.dart';
import 'cobranzas_modelos.dart';

/// Pantalla principal de Cuentas por Cobrar (Cobranzas).
/// Agrupa por cliente/factura: una sola fila por crédito activo con su próximo pago,
/// soporte de abonos en cascada y visualización del historial completo.
class CobranzasPage extends StatefulWidget {
  const CobranzasPage({super.key});

  @override
  State<CobranzasPage> createState() => _CobranzasPageState();
}

class _CobranzasPageState extends State<CobranzasPage> {
  final _busqueda = TextEditingController();
  String _filtroEstado = 'activos'; // 'activos', 'vencidos', 'saldados'

  late Future<List<CreditoCobranza>> _futuroCreditos;
  late Future<ResumenCobranza> _futuroResumen;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _recargar() {
    setState(() {
      _futuroCreditos = BaseDatos.instancia.listarCreditosCobranza(
        filtro: _busqueda.text,
        filtroEstado: _filtroEstado,
      );
      _futuroResumen = BaseDatos.instancia.obtenerResumenCobranza();
    });
  }

  Future<void> _abrirFactura(int facturaId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FacturaDetallePage(facturaId: facturaId),
      ),
    );
    if (!mounted) return;
    _recargar();
  }

  /// Muestra el desglose de todas las cuotas de este crédito en un diálogo modal
  void _verHistorialCuotas(CreditoCobranza c) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scroll) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c.numeroFacturaTexto} · ${c.clienteNombre}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Plan: ${c.cantidadCuotas} cuotas ${c.frecuenciaPago}es · Saldo: ${formatoMoneda(c.saldoPendiente)}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.separated(
                controller: scroll,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: c.cuotas.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final cuota = c.cuotas[i];
                  final dias = diasHasta(cuota.fechaVencimiento);
                  final estaVencida =
                      !cuota.pagada && dias != null && dias < 0;

                  Widget leadingIcon;
                  if (cuota.pagada) {
                    leadingIcon = const CircleAvatar(
                      backgroundColor: Color(0xFFE8F5E9),
                      child: Icon(Icons.check, color: Colors.green),
                    );
                  } else if (cuota.esAbonoParcial) {
                    leadingIcon = CircleAvatar(
                      backgroundColor: Colors.amber.shade100,
                      child: Text('${cuota.numero}',
                          style: TextStyle(
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.bold)),
                    );
                  } else if (estaVencida) {
                    leadingIcon = CircleAvatar(
                      backgroundColor: Colors.red.shade100,
                      child: Text('${cuota.numero}',
                          style: TextStyle(
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.bold)),
                    );
                  } else {
                    leadingIcon = CircleAvatar(
                      backgroundColor: Colors.blue.shade50,
                      child: Text('${cuota.numero}',
                          style: TextStyle(
                              color: Colors.blue.shade900,
                              fontWeight: FontWeight.bold)),
                    );
                  }

                  return ListTile(
                    leading: leadingIcon,
                    title: Text(
                      'Cuota ${cuota.numero} de ${c.cantidadCuotas} · ${formatoMoneda(cuota.monto)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cuota.pagada
                              ? 'Pagada el ${formatoFecha(cuota.fechaPago)}'
                              : 'Vence el ${formatoFecha(cuota.fechaVencimiento)}'
                                  '${estaVencida ? ' · vencida hace ${-dias} días' : ''}',
                          style: TextStyle(
                            color: estaVencida ? Colors.red.shade800 : null,
                          ),
                        ),
                        if (cuota.esAbonoParcial)
                          Text(
                            'Abonado: ${formatoMoneda(cuota.montoPagado)} · Restan: ${formatoMoneda(cuota.saldo)}',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    trailing: cuota.pagada
                        ? const Chip(
                            avatar: Icon(Icons.check, size: 16, color: Colors.green),
                            label: Text('Saldada'),
                          )
                        : (cuota.esAbonoParcial
                            ? Chip(
                                label: Text('Resta ${formatoMoneda(cuota.saldo)}'),
                                backgroundColor: Colors.amber.shade50,
                              )
                            : Chip(
                                label: Text(formatoMoneda(cuota.saldo)),
                              )),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Diálogo interactivo para registrar un abono flexible (en cascada)
  Future<void> _abrirDialogoAbono(CreditoCobranza c) async {
    final prox = c.proximaCuota;
    final montoInicialSugerido = prox?.saldo ?? c.saldoPendiente;
    final moraSugerida = c.moraSugerida;
    var aplicarMora = moraSugerida > 0;
    var metodoPago = bancosDominicanos.first;

    final abonoCtrl = TextEditingController(
      text: formatoCantidad(montoInicialSugerido),
    );
    final refCtrl = TextEditingController();
    final notasCtrl = TextEditingController();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final montoAbono = leerNumero(abonoCtrl.text) ?? 0.0;
          final moraFinal = aplicarMora ? moraSugerida : 0.0;
          final totalCobro = montoAbono + moraFinal;

          // Simulación en vivo de cómo se aplicará el abono
          var restanteSim = montoAbono;
          var cuotasSaldadasSim = 0;
          var cuotasParcialesSim = 0;
          for (final cuota in c.cuotas) {
            if (cuota.pagada) continue;
            if (restanteSim <= 0) break;
            if (restanteSim >= cuota.saldo - 0.0001) {
              cuotasSaldadasSim++;
              restanteSim -= cuota.saldo;
            } else {
              cuotasParcialesSim++;
              restanteSim = 0;
            }
          }

          return AlertDialog(
            title: Text('Registrar Abono · ${c.numeroFacturaTexto}'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.clienteNombre,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'Saldo total restante: ${formatoMoneda(c.saldoPendiente)}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const Divider(height: 24),
                    TextField(
                      controller: abonoCtrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Monto a abonar (RD\$) *',
                        hintText: '0.00',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.all_inclusive),
                          tooltip: 'Saldar deuda completa',
                          onPressed: () {
                            setModalState(() {
                              abonoCtrl.text = formatoCantidad(c.saldoPendiente);
                            });
                          },
                        ),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 8),

                    // Explicación en vivo de la aplicación en cascada
                    if (montoAbono > 0)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.primaryContainer.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          cuotasSaldadasSim > 0 && cuotasParcialesSim > 0
                              ? 'Este abono liquidará $cuotasSaldadasSim cuota(s) completa(s) y abonará a la siguiente cuota.'
                              : (cuotasSaldadasSim > 0
                                  ? 'Este abono liquidará $cuotasSaldadasSim cuota(s) completa(s).'
                                  : 'Este abono se aplicará como pago parcial a la cuota actual.'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(ctx).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    if (c.proximaEstaVencida) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: aplicarMora,
                                  onChanged: (v) {
                                    setModalState(() => aplicarMora = v ?? true);
                                  },
                                ),
                                Expanded(
                                  child: Text(
                                    'Cobrar mora (${formatoCantidad(c.moraPct)}%): + ${formatoMoneda(moraSugerida)}',
                                    style: TextStyle(
                                      color: Colors.red.shade900,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total a recibir:',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        Text(
                          formatoMoneda(totalCobro),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(ctx).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: metodoPago,
                      decoration: const InputDecoration(
                        labelText: 'Método / Banco de recepción *',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final b in bancosDominicanos)
                          DropdownMenuItem(value: b, child: Text(b)),
                      ],
                      onChanged: (v) =>
                          setModalState(() => metodoPago = v ?? metodoPago),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: refCtrl,
                      decoration: const InputDecoration(
                        labelText: 'No. de Voucher / Referencia bancaria',
                        hintText: 'Ej. 048291 / TRX-48201',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notasCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nota adicional (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: montoAbono <= 0 ? null : () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Confirmar abono'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmado != true || !mounted) return;

    final abonoFinal = leerNumero(abonoCtrl.text) ?? 0.0;
    if (abonoFinal <= 0) return;

    try {
      await BaseDatos.instancia.registrarAbonoFactura(
        facturaId: c.facturaId,
        montoAbono: abonoFinal,
        moraCobrada: aplicarMora ? moraSugerida : 0.0,
        metodoPago: metodoPago,
        referencia: refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
        usuarioNombre: Sesion.instancia.nombreUsuario,
        notas: notasCtrl.text.trim().isEmpty ? null : notasCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Abono de ${formatoMoneda(abonoFinal)} registrado exitosamente a ${c.clienteNombre}.',
          ),
          backgroundColor: Colors.green.shade800,
        ),
      );
      _recargar();
    } catch (e) {
      if (!mounted) return;
      aviso(context, e is StateError ? e.message : 'No se pudo registrar el abono: $e');
    }
  }

  Widget _tarjetaKpi(
    String titulo,
    String valor, {
    String? subtitulo,
    Color? color,
    IconData? icono,
  }) {
    return Expanded(
      child: Card(
        elevation: 1,
        color: color != null ? color.withOpacity(0.08) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icono != null) ...[
                    Icon(icono, size: 18, color: color),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color ?? Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                valor,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (subtitulo != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipEstadoCredito(CreditoCobranza c) {
    if (c.saldada) {
      return Chip(
        avatar: const Icon(Icons.check_circle, size: 16, color: Colors.green),
        label: const Text('Saldado al 100%'),
        backgroundColor: Colors.green.shade50,
        side: BorderSide(color: Colors.green.shade200),
      );
    }
    if (c.proximaEstaVencida) {
      final dias = -c.diasHastaProximoVencimiento!;
      return Chip(
        avatar: const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
        label: Text(dias == 1 ? 'Vencida ayer' : 'Vencida hace $dias días'),
        backgroundColor: Colors.red.shade50,
        side: BorderSide(color: Colors.red.shade300),
      );
    }
    if (c.proximaVenceHoy) {
      return Chip(
        avatar: const Icon(Icons.alarm, size: 16, color: Colors.orange),
        label: const Text('Vence Hoy'),
        backgroundColor: Colors.orange.shade50,
        side: BorderSide(color: Colors.orange.shade300),
      );
    }
    final dias = c.diasHastaProximoVencimiento;
    if (dias == null) return const SizedBox.shrink();
    return Chip(
      avatar: const Icon(Icons.schedule, size: 16, color: Colors.blue),
      label: Text(dias == 1 ? 'Vence mañana' : 'En $dias días'),
      backgroundColor: Colors.blue.shade50,
      side: BorderSide(color: Colors.blue.shade200),
    );
  }

  /// Tarjeta única por cliente y factura a crédito
  Widget _tarjetaCredito(CreditoCobranza c) {
    final prox = c.proximaCuota;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: Cliente, Factura y Estado general
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.clienteNombre,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${c.numeroFacturaTexto} · ${c.cantidadCuotas} cuotas ${c.frecuenciaPago}es'
                        '${c.clienteTelefono != null && c.clienteTelefono!.isNotEmpty ? ' · Tel: ${c.clienteTelefono}' : ''}',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                _chipEstadoCredito(c),
              ],
            ),
            const SizedBox(height: 12),

            // Barra de progreso del financiamiento
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saldo pendiente: ${formatoMoneda(c.saldoPendiente)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: c.saldada ? Colors.green.shade800 : Colors.red.shade900,
                  ),
                ),
                Text(
                  'Financiado: ${formatoMoneda(c.totalFinanciado)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: c.totalFinanciado > 0
                    ? (c.totalPagadoCapital / c.totalFinanciado).clamp(0.0, 1.0)
                    : 1.0,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                color: c.saldada ? Colors.green : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${formatoCantidad(c.porcentajePagado)}% pagado · ${c.cuotasPagadasCount} de ${c.cantidadCuotas} cuotas saldadas',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),

            // Cuadro del Próximo Pago si no está saldada
            if (!c.saldada && prox != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.proximaEstaVencida
                      ? Colors.red.shade50
                      : Colors.blue.shade50.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: c.proximaEstaVencida
                        ? Colors.red.shade200
                        : Colors.blue.shade100,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      c.proximaEstaVencida
                          ? Icons.warning_amber_rounded
                          : Icons.calendar_today,
                      color: c.proximaEstaVencida
                          ? Colors.red.shade700
                          : Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Próximo pago: Cuota ${prox.numero} de ${c.cantidadCuotas} · Vence ${formatoFecha(prox.fechaVencimiento)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: c.proximaEstaVencida
                                  ? Colors.red.shade900
                                  : Colors.black87,
                            ),
                          ),
                          Text(
                            prox.esAbonoParcial
                                ? 'Resta de esta cuota: ${formatoMoneda(prox.saldo)} (Abonado: ${formatoMoneda(prox.montoPagado)} de ${formatoMoneda(prox.monto)})'
                                : 'Monto de cuota: ${formatoMoneda(prox.saldo)}'
                                    '${c.proximaEstaVencida && c.moraPct > 0 ? ' · Mora: +${formatoMoneda(c.moraSugerida)}' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: c.proximaEstaVencida
                                  ? Colors.red.shade800
                                  : Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Botones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _verHistorialCuotas(c),
                  icon: const Icon(Icons.list_alt, size: 18),
                  label: const Text('Ver cuotas'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _abrirFactura(c.facturaId),
                  child: const Text('Factura'),
                ),
                if (!c.saldada) ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _abrirDialogoAbono(c),
                    icon: const Icon(Icons.payment, size: 18),
                    label: const Text('Abonar / Pagar'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuentas por Cobrar (Cobranzas)'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _recargar,
          ),
        ],
      ),
      body: Column(
        children: [
          // Tarjetas de Resumen KPI
          FutureBuilder<ResumenCobranza>(
            future: _futuroResumen,
            builder: (context, snap) {
              final r = snap.data;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    _tarjetaKpi(
                      'Por cobrar',
                      r == null ? '—' : formatoMoneda(r.totalPorCobrar),
                      icono: Icons.pending_actions,
                      color: Colors.blue.shade800,
                    ),
                    _tarjetaKpi(
                      'Vencido en mora',
                      r == null ? '—' : formatoMoneda(r.totalVencido),
                      subtitulo: r == null
                          ? null
                          : '${r.cantidadCreditosVencidos} crédito(s)',
                      icono: Icons.error_outline,
                      color: r != null && r.cantidadCreditosVencidos > 0
                          ? Colors.red.shade700
                          : Colors.grey.shade700,
                    ),
                    _tarjetaKpi(
                      'Cobrado este mes',
                      r == null ? '—' : formatoMoneda(r.cobradoEsteMes),
                      icono: Icons.savings_outlined,
                      color: Colors.green.shade800,
                    ),
                  ],
                ),
              );
            },
          ),

          // Buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _busqueda,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Buscar por cliente, teléfono o factura (FAC-0001)...',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _busqueda.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _busqueda.clear();
                          _recargar();
                        },
                      )
                    : null,
              ),
              onChanged: (_) => _recargar(),
            ),
          ),

          // Filtros
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Créditos activos'),
                  selected: _filtroEstado == 'activos',
                  onSelected: (s) {
                    if (s) {
                      setState(() => _filtroEstado = 'activos');
                      _recargar();
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Atrasados en mora'),
                  selected: _filtroEstado == 'vencidos',
                  selectedColor: Colors.red.shade100,
                  onSelected: (s) {
                    if (s) {
                      setState(() => _filtroEstado = 'vencidos');
                      _recargar();
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Saldados'),
                  selected: _filtroEstado == 'saldados',
                  selectedColor: Colors.green.shade100,
                  onSelected: (s) {
                    if (s) {
                      setState(() => _filtroEstado = 'saldados');
                      _recargar();
                    }
                  },
                ),
              ],
            ),
          ),

          const Divider(height: 12),

          // Lista de Créditos (una tarjeta por factura)
          Expanded(
            child: FutureBuilder<List<CreditoCobranza>>(
              future: _futuroCreditos,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Error al cargar cobranzas: ${snap.error}'),
                    ),
                  );
                }
                final creditos = snap.data ?? [];
                if (creditos.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _filtroEstado == 'saldados'
                                ? Icons.task_alt
                                : Icons.check_circle_outline,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _filtroEstado == 'vencidos'
                                ? '¡Excelente! No hay créditos con cuotas vencidas.'
                                : (_filtroEstado == 'saldados'
                                    ? 'No hay créditos saldados con ese filtro.'
                                    : 'No hay créditos activos por cobrar.'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: creditos.length,
                  itemBuilder: (context, i) => _tarjetaCredito(creditos[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
