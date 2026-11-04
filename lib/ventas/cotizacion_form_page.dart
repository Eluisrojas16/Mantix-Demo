import 'package:flutter/material.dart';

import '../data/aires_db.dart';
import '../data/base_datos.dart';
import '../inventario/layout.dart';
import '../inventario/modelos.dart' show ProductoConStock;
import '../models/cliente.dart';
import '../utils/fechas.dart';
import '../utils/numeros.dart';
import 'linea_dialogo.dart';
import 'modelos.dart';
import 'seleccionar_cliente_page.dart';
import 'seleccionar_producto_page.dart';
import 'ventas_db.dart';

/// Formulario para crear o editar una cotización. Al guardar devuelve su id.
class CotizacionFormPage extends StatefulWidget {
  final Cotizacion? cotizacion;
  const CotizacionFormPage({super.key, this.cotizacion});

  @override
  State<CotizacionFormPage> createState() => _CotizacionFormPageState();
}

class _CotizacionFormPageState extends State<CotizacionFormPage> {
  Negocio _negocio = const Negocio(nombre: '');
  Cliente? _cliente;
  late DateTime _fecha = deIso(widget.cotizacion?.fecha) ?? hoySinHora();
  late DateTime _vigencia =
      deIso(widget.cotizacion?.vigenciaHasta) ?? hoySinHora();
  late String _estado = widget.cotizacion?.estado ?? 'borrador';
  List<LineaVenta> _lineas = [];
  final _notas = TextEditingController();
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _notas.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final negocio = await BaseDatos.instancia.obtenerNegocio();
    final c = widget.cotizacion;
    Cliente? cliente;
    var lineas = <LineaVenta>[];
    if (c != null) {
      cliente = await BaseDatos.instancia.obtenerCliente(c.clienteId);
      lineas = await BaseDatos.instancia.listarLineasCotizacion(c.id!);
    }
    if (!mounted) return;
    setState(() {
      _negocio = negocio;
      _cliente = cliente;
      _lineas = lineas;
      if (c == null) {
        _vigencia = DateTime(
          _fecha.year,
          _fecha.month,
          _fecha.day + negocio.vigenciaDias,
        );
        _notas.text = negocio.condiciones ?? '';
      } else {
        _notas.text = c.notas ?? '';
      }
      _cargando = false;
    });
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  // ------------------------------------------------------------ cliente y fechas

  Future<void> _elegirCliente() async {
    final c = await Navigator.of(context).push<Cliente>(
      MaterialPageRoute(builder: (_) => const SeleccionarClientePage()),
    );
    if (c != null && mounted) setState(() => _cliente = c);
  }

  Future<void> _elegirFecha({required bool esVigencia}) async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: esVigencia ? _vigencia : _fecha,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (elegida == null || !mounted) return;
    setState(() {
      if (esVigencia) {
        _vigencia = elegida;
      } else {
        _fecha = elegida;
        if (_vigencia.isBefore(_fecha)) {
          _vigencia = DateTime(
            _fecha.year,
            _fecha.month,
            _fecha.day + _negocio.vigenciaDias,
          );
        }
      }
    });
  }

  Widget _campoFecha(String etiqueta, DateTime valor, bool esVigencia) {
    return InkWell(
      onTap: () => _elegirFecha(esVigencia: esVigencia),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: etiqueta,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(formatoFecha(aIso(valor))),
      ),
    );
  }

  // ------------------------------------------------------------ líneas

  Future<void> _agregarProducto() async {
    final item = await Navigator.of(context).push<ProductoConStock>(
      MaterialPageRoute(builder: (_) => const SeleccionarProductoPage()),
    );
    if (item == null || !mounted) return;
    final p = item.producto;
    final detalle =
        [p.marcaNombre, p.modeloNombre].whereType<String>().join(' ');
    final linea = await editarLinea(
      context,
      LineaVenta(
        productoId: p.id,
        descripcion: detalle.isEmpty ? p.nombre : '${p.nombre} · $detalle',
        unidad: p.unidad,
        precioUnitario: p.precioVenta ?? 0,
        itbisPct: _negocio.itbisPorcentaje,
      ),
    );
    if (linea != null && mounted) setState(() => _lineas = [..._lineas, linea]);
  }

  Future<void> _agregarConcepto() async {
    final linea = await editarLinea(
      context,
      LineaVenta(descripcion: '', itbisPct: _negocio.itbisPorcentaje),
    );
    if (linea != null && mounted) setState(() => _lineas = [..._lineas, linea]);
  }

  Future<void> _editarLinea(int i) async {
    final linea = await editarLinea(context, _lineas[i]);
    if (linea == null || !mounted) return;
    setState(() {
      final copia = [..._lineas];
      copia[i] = linea;
      _lineas = copia;
    });
  }

  void _quitarLinea(int i) {
    setState(() {
      final copia = [..._lineas];
      copia.removeAt(i);
      _lineas = copia;
    });
  }

  // ------------------------------------------------------------ guardar

  Future<void> _guardar() async {
    if (_cliente == null) {
      _aviso('Elige un cliente.');
      return;
    }
    if (_lineas.isEmpty) {
      _aviso('Agrega al menos un artículo o concepto.');
      return;
    }
    if (_vigencia.isBefore(_fecha)) {
      _aviso('La vigencia no puede ser anterior a la fecha.');
      return;
    }
    setState(() => _guardando = true);
    final notas = _notas.text.trim();
    final c = Cotizacion(
      id: widget.cotizacion?.id,
      clienteId: _cliente!.id!,
      fecha: aIso(_fecha),
      vigenciaHasta: aIso(_vigencia),
      estado: _estado,
      notas: notas.isEmpty ? null : notas,
    );
    try {
      final id = await BaseDatos.instancia.guardarCotizacion(c, _lineas);
      if (!mounted) return;
      Navigator.pop(context, id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _aviso('No se pudo guardar: $e');
    }
  }

  // ------------------------------------------------------------ pantalla

  @override
  Widget build(BuildContext context) {
    final esNueva = widget.cotizacion == null;
    final totales = Totales.de(_lineas);
    final cli = _cliente;

    return Scaffold(
      appBar: AppBar(
        title: Text(esNueva ? 'Nueva cotización' : 'Editar ${widget.cotizacion!.numero}'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: ListTile(
                        leading: Icon(
                          cli != null && cli.esEmpresa
                              ? Icons.business
                              : Icons.person,
                        ),
                        title: Text(cli?.nombreApellido ?? 'Sin cliente'),
                        subtitle: Text(
                          cli == null
                              ? 'Elige a quién va dirigida la cotización'
                              : [
                                  if (cli.esEmpresa && cli.rnc != null)
                                    'RNC ${cli.rnc}',
                                  if (!cli.esEmpresa && cli.cedula != null)
                                    'Cédula ${cli.cedula}',
                                  if (cli.telefono != null) cli.telefono!,
                                ].join(' · '),
                        ),
                        trailing: FilledButton.tonal(
                          onPressed: _elegirCliente,
                          child: Text(cli == null ? 'Elegir' : 'Cambiar'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CamposResponsivos(
                      hijos: [
                        _campoFecha('Fecha', _fecha, false),
                        _campoFecha('Válida hasta', _vigencia, true),
                        DropdownButtonFormField<String>(
                          initialValue: _estado,
                          decoration: const InputDecoration(
                            labelText: 'Estado',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final k in estadosCotizacionEditables)
                              DropdownMenuItem(
                                value: k,
                                child: Text(estadosCotizacion[k]!),
                              ),
                          ],
                          onChanged: (v) =>
                              setState(() => _estado = v ?? _estado),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Artículos y conceptos',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _agregarProducto,
                          icon: const Icon(Icons.inventory_2),
                          label: const Text('Agregar artículo'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _agregarConcepto,
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Agregar concepto'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_lineas.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'Todavía no hay líneas. Un concepto sirve para '
                            'mano de obra, instalación u otros cobros sin inventario.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    for (var i = 0; i < _lineas.length; i++)
                      Card(
                        child: ListTile(
                          title: Text(_lineas[i].descripcion),
                          subtitle: Text(
                            '${formatoCantidad(_lineas[i].cantidad)} ${_lineas[i].unidad}'
                            ' × ${formatoMoneda(_lineas[i].precioUnitario)}'
                            '${_lineas[i].descuentoPct > 0 ? ' · desc. ${formatoCantidad(_lineas[i].descuentoPct)}%' : ''}'
                            ' · ITBIS ${formatoCantidad(_lineas[i].itbisPct)}%',
                          ),
                          onTap: () => _editarLinea(i),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formatoMoneda(_lineas[i].total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Quitar',
                                icon: const Icon(Icons.close),
                                onPressed: () => _quitarLinea(i),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _filaTotal('Subtotal', totales.subtotal),
                            _filaTotal('ITBIS', totales.itbis),
                            const Divider(),
                            _filaTotal('Total', totales.total, fuerte: true),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _notas,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Condiciones o notas',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _guardando ? null : _guardar,
                      icon: const Icon(Icons.save),
                      label: Text(_guardando ? 'Guardando...' : 'Guardar'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _filaTotal(String texto, double valor, {bool fuerte = false}) {
    final estilo = fuerte
        ? Theme.of(context).textTheme.titleLarge
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(texto, style: estilo),
          Text(formatoMoneda(valor), style: estilo),
        ],
      ),
    );
  }
}
