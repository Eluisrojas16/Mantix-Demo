import 'package:flutter/material.dart';

import '../data/base_datos.dart';
import '../utils/fechas.dart';
import '../utils/numeros.dart';
import 'catalogos_db.dart';
import 'dialogos.dart';
import 'inventario_db.dart';
import 'layout.dart';
import 'modelos.dart';
import 'seriales.dart';
import 'seriales_db.dart';

const _unidadesComunes = ['unidad', 'metro', 'libra', 'kg', 'galón', 'caja'];

/// Valor especial de las listas desplegables: "+ Agregar nueva...".
const _agregar = -1;

/// Formulario para crear o editar un producto, material o misceláneo.
class ProductoFormPage extends StatefulWidget {
  final Producto? producto;
  const ProductoFormPage({super.key, this.producto});

  @override
  State<ProductoFormPage> createState() => _ProductoFormPageState();
}

class _ProductoFormPageState extends State<ProductoFormPage> {
  final _formKey = GlobalKey<FormState>();
  late String _clase = widget.producto?.clase ?? 'producto';
  late bool _activo = widget.producto?.activo ?? true;
  late bool _serial = widget.producto?.manejaSerial ?? false;
  late int? _categoriaId = widget.producto?.categoriaId;
  late int? _marcaId = widget.producto?.marcaId;
  late int? _modeloId = widget.producto?.modeloId;
  List<ItemCatalogo> _categorias = [];
  List<ItemCatalogo> _marcas = [];
  List<ItemCatalogo> _modelos = [];
  bool _cargando = true;
  bool _guardando = false;

  /// Un producto que ya tiene movimientos no puede cambiar su forma de control.
  bool _bloqueaSerial = false;

  /// Se incrementa para obligar a las listas desplegables a mostrar el valor actual.
  int _ver = 0;

  late final _nombre = TextEditingController(text: widget.producto?.nombre);
  late final _codigo = TextEditingController(text: widget.producto?.codigo);
  late final _parte =
      TextEditingController(text: widget.producto?.numeroParte);
  late final _descripcion =
      TextEditingController(text: widget.producto?.descripcion);
  late final _unidad =
      TextEditingController(text: widget.producto?.unidad ?? 'unidad');
  late final _costo = TextEditingController(
    text: widget.producto?.costo == null
        ? ''
        : formatoCantidad(widget.producto!.costo!),
  );
  late final _precio = TextEditingController(
    text: widget.producto?.precioVenta == null
        ? ''
        : formatoCantidad(widget.producto!.precioVenta!),
  );
  late final _minimo = TextEditingController(
    text: (widget.producto?.stockMinimo ?? 0) == 0
        ? ''
        : formatoCantidad(widget.producto!.stockMinimo),
  );
  final _inicial = TextEditingController();
  final _serialesIniciales = TextEditingController();

  bool get _controla => _clase != 'miscelaneo';

  @override
  void initState() {
    super.initState();
    _cargarCatalogos();
  }

  @override
  void dispose() {
    for (final c in [
      _nombre,
      _codigo,
      _parte,
      _descripcion,
      _unidad,
      _costo,
      _precio,
      _minimo,
      _inicial,
      _serialesIniciales,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarCatalogos() async {
    final cats = await BaseDatos.instancia.listarCategorias();
    final marcas = await BaseDatos.instancia.listarMarcas();
    final modelos = _marcaId == null
        ? <ItemCatalogo>[]
        : await BaseDatos.instancia.listarModelosDe(_marcaId!);
    final bloquea = widget.producto == null
        ? false
        : await BaseDatos.instancia.tieneMovimientos(widget.producto!.id!);
    if (!mounted) return;
    setState(() {
      _categorias = cats;
      _marcas = marcas;
      _modelos = modelos;
      _bloqueaSerial = bloquea;
      _cargando = false;
    });
  }

  // ------------------------------------------------------------ listas desplegables

  Future<void> _cambiarMarca(int? id) async {
    final modelos = id == null
        ? <ItemCatalogo>[]
        : await BaseDatos.instancia.listarModelosDe(id);
    if (!mounted) return;
    setState(() {
      _marcaId = id;
      _modeloId = null;
      _modelos = modelos;
      _ver++;
    });
  }

  Future<void> _agregarMarca() async {
    final n = await pedirTexto(context, titulo: 'Nueva marca');
    if (!mounted) return;
    if (n == null) {
      setState(() => _ver++);
      return;
    }
    final id = await BaseDatos.instancia.crearMarca(n);
    final marcas = await BaseDatos.instancia.listarMarcas();
    final modelos = await BaseDatos.instancia.listarModelosDe(id);
    if (!mounted) return;
    setState(() {
      _marcas = marcas;
      _marcaId = id;
      _modelos = modelos;
      _modeloId = null;
      _ver++;
    });
  }

  Future<void> _agregarModelo() async {
    final marcaId = _marcaId;
    if (marcaId == null) return;
    final n = await pedirTexto(context, titulo: 'Nuevo modelo');
    if (!mounted) return;
    if (n == null) {
      setState(() => _ver++);
      return;
    }
    final id = await BaseDatos.instancia.crearModelo(marcaId, n);
    final modelos = await BaseDatos.instancia.listarModelosDe(marcaId);
    if (!mounted) return;
    setState(() {
      _modelos = modelos;
      _modeloId = id;
      _ver++;
    });
  }

  Future<void> _agregarCategoria() async {
    final n = await pedirTexto(context, titulo: 'Nueva categoría');
    if (!mounted) return;
    if (n == null) {
      setState(() => _ver++);
      return;
    }
    final id = await BaseDatos.instancia.crearCategoria(n);
    final cats = await BaseDatos.instancia.listarCategorias();
    if (!mounted) return;
    setState(() {
      _categorias = cats;
      _categoriaId = id;
      _ver++;
    });
  }

  Widget _selector({
    required String clave,
    required String etiqueta,
    required int? valor,
    required List<ItemCatalogo> items,
    required String textoAgregar,
    required ValueChanged<int?> alCambiar,
    required VoidCallback alAgregar,
    bool habilitado = true,
    String? ayuda,
  }) {
    return DropdownButtonFormField<int?>(
      key: ValueKey('$clave-$valor-$_ver'),
      initialValue: valor,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: etiqueta,
        helperText: ayuda,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('— Ninguna —')),
        for (final i in items)
          DropdownMenuItem<int?>(value: i.id, child: Text(i.nombre)),
        DropdownMenuItem<int?>(
          value: _agregar,
          child: Text(
            textoAgregar,
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ),
      ],
      onChanged: habilitado
          ? (v) {
              if (v == _agregar) {
                alAgregar();
              } else {
                alCambiar(v);
              }
            }
          : null,
    );
  }

  // ------------------------------------------------------------ campos de texto

  String? _vacioANulo(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  String? _validarNumero(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final n = leerNumero(t);
    if (n == null) return 'Número inválido';
    if (n < 0) return 'No puede ser negativo';
    return null;
  }

  Widget _texto(
    TextEditingController c,
    String etiqueta, {
    String? ayuda,
    TextInputType? teclado,
    int maxLineas = 1,
    TextCapitalization capitalizar = TextCapitalization.none,
    String? Function(String?)? validar,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: teclado,
      maxLines: maxLineas,
      textCapitalization: capitalizar,
      decoration: InputDecoration(
        labelText: etiqueta,
        helperText: ayuda,
        border: const OutlineInputBorder(),
      ),
      validator: validar,
    );
  }

  // ------------------------------------------------------------ guardar

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final conSerial = _controla && _serial;
    final esNuevo = widget.producto == null;

    // Seriales iniciales: se revisan ANTES de guardar el producto.
    var serialesIniciales = <String>[];
    if (esNuevo && conSerial) {
      serialesIniciales = parsearSeriales(_serialesIniciales.text);
      final repetidos = serialesRepetidos(serialesIniciales);
      if (repetidos.isNotEmpty) {
        _aviso('Hay seriales repetidos en la lista: ${repetidos.join(', ')}');
        return;
      }
      if (serialesIniciales.isNotEmpty) {
        final existentes =
            await BaseDatos.instancia.serialesExistentes(serialesIniciales);
        if (existentes.isNotEmpty) {
          if (!mounted) return;
          _aviso(
            'Estos seriales ya están registrados: ${existentes.take(5).join(', ')}',
          );
          return;
        }
      }
    }
    if (!mounted) return;
    setState(() => _guardando = true);

    final producto = Producto(
      id: widget.producto?.id,
      clase: _clase,
      codigo: _vacioANulo(_codigo.text),
      nombre: _nombre.text.trim(),
      categoriaId: _categoriaId,
      // Un misceláneo es un concepto: no lleva marca, modelo ni número de parte.
      marcaId: _controla ? _marcaId : null,
      modeloId: _controla ? _modeloId : null,
      numeroParte: _controla ? _vacioANulo(_parte.text) : null,
      descripcion: _vacioANulo(_descripcion.text),
      unidad: _vacioANulo(_unidad.text) ?? 'unidad',
      costo: leerNumero(_costo.text),
      precioVenta: leerNumero(_precio.text),
      stockMinimo: _controla ? (leerNumero(_minimo.text) ?? 0) : 0,
      activo: _activo,
      manejaSerial: conSerial,
    );

    try {
      final id = await BaseDatos.instancia.guardarProducto(producto);

      if (esNuevo && _controla) {
        if (conSerial) {
          // Existencia inicial con seriales: una entrada con cada serial.
          if (serialesIniciales.isNotEmpty) {
            await BaseDatos.instancia.registrarEntradaSeriales(
              productoId: id,
              fecha: aIso(hoySinHora()),
              seriales: serialesIniciales,
              costoUnitario: producto.costo,
              origen: 'inicial',
              nota: 'Existencia inicial',
            );
          }
        } else {
          // Existencia inicial por cantidad: una entrada.
          final inicial = leerNumero(_inicial.text);
          if (inicial != null && inicial > 0) {
            await BaseDatos.instancia.registrarMovimiento(
              Movimiento(
                productoId: id,
                fecha: aIso(hoySinHora()),
                tipo: 'entrada',
                cantidad: inicial,
                costoUnitario: producto.costo,
                origen: 'inicial',
                nota: 'Existencia inicial',
              ),
            );
          }
        }
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _aviso(
        e is StateError
            ? e.message
            : (e.toString().contains('UNIQUE')
                ? 'Ya existe un producto con ese código.'
                : 'No se pudo guardar: $e'),
      );
    }
  }

  // ------------------------------------------------------------ pantalla

  @override
  Widget build(BuildContext context) {
    final esNuevo = widget.producto == null;
    const decimales = TextInputType.numberWithOptions(decimal: true);

    return Scaffold(
      appBar: AppBar(
        title: Text(esNuevo ? 'Nuevo producto' : 'Editar producto'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      CamposResponsivos(
                        hijos: [
                          const TituloSeccion('Datos generales'),
                          _texto(
                            _nombre,
                            'Nombre *',
                            capitalizar: TextCapitalization.sentences,
                            validar: (v) => (v == null || v.trim().isEmpty)
                                ? 'El nombre es obligatorio'
                                : null,
                          ),
                          _texto(
                            _codigo,
                            'Código o SKU',
                            ayuda: 'Opcional, no se puede repetir',
                          ),
                          CampoCompleto(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SegmentedButton<String>(
                                  showSelectedIcon: false,
                                  segments: [
                                    for (final e
                                        in clasesProductoCortas.entries)
                                      ButtonSegment<String>(
                                        value: e.key,
                                        label: Text(e.value),
                                      ),
                                  ],
                                  selected: {_clase},
                                  onSelectionChanged: (s) =>
                                      setState(() => _clase = s.first),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  ayudaClase[_clase] ?? '',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const TituloSeccion('Clasificación'),
                          _selector(
                            clave: 'categoria',
                            etiqueta: 'Categoría',
                            valor: _categoriaId,
                            items: _categorias,
                            textoAgregar: '+ Agregar categoría…',
                            alCambiar: (v) => setState(() {
                              _categoriaId = v;
                              _ver++;
                            }),
                            alAgregar: _agregarCategoria,
                          ),
                          if (_controla) ...[
                            _selector(
                              clave: 'marca',
                              etiqueta: 'Marca',
                              valor: _marcaId,
                              items: _marcas,
                              textoAgregar: '+ Agregar marca…',
                              alCambiar: _cambiarMarca,
                              alAgregar: _agregarMarca,
                            ),
                            _selector(
                              clave: 'modelo-$_marcaId',
                              etiqueta: 'Modelo',
                              valor: _modeloId,
                              items: _modelos,
                              textoAgregar: '+ Agregar modelo…',
                              alCambiar: (v) => setState(() {
                                _modeloId = v;
                                _ver++;
                              }),
                              alAgregar: _agregarModelo,
                              habilitado: _marcaId != null,
                              ayuda: _marcaId == null
                                  ? 'Elige primero la marca'
                                  : null,
                            ),
                            _texto(_parte, 'Número de parte'),
                          ],
                          CampoCompleto(
                            _texto(
                              _descripcion,
                              'Descripción o características',
                              maxLineas: 3,
                              capitalizar: TextCapitalization.sentences,
                            ),
                          ),
                          const TituloSeccion('Precios y existencias'),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _texto(_unidad, 'Unidad de medida'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  for (final u in _unidadesComunes)
                                    ActionChip(
                                      label: Text(u),
                                      onPressed: () =>
                                          setState(() => _unidad.text = u),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          _texto(
                            _costo,
                            'Costo',
                            teclado: decimales,
                            validar: _validarNumero,
                          ),
                          _texto(
                            _precio,
                            'Precio de venta',
                            teclado: decimales,
                            validar: _validarNumero,
                          ),
                          if (_controla) ...[
                            CampoCompleto(
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Controlar por número de serie',
                                ),
                                subtitle: Text(
                                  _bloqueaSerial
                                      ? 'No se puede cambiar: este producto ya tiene movimientos.'
                                      : 'Cada unidad tiene un serial único y se despacha por serial '
                                          '(ideal para aires acondicionados).',
                                ),
                                value: _serial,
                                onChanged: _bloqueaSerial
                                    ? null
                                    : (v) => setState(() => _serial = v),
                              ),
                            ),
                            _texto(
                              _minimo,
                              'Stock mínimo',
                              ayuda:
                                  'Avisa cuando la existencia llegue a esta cantidad',
                              teclado: decimales,
                              validar: _validarNumero,
                            ),
                            if (esNuevo && !_serial)
                              _texto(
                                _inicial,
                                'Existencia inicial',
                                ayuda: 'Cuántos tienes ahora mismo (opcional)',
                                teclado: decimales,
                                validar: _validarNumero,
                              ),
                            if (esNuevo && _serial)
                              CampoCompleto(
                                _texto(
                                  _serialesIniciales,
                                  'Seriales iniciales',
                                  ayuda:
                                      'Uno por línea, los que tienes ahora mismo (opcional). '
                                      'Después puedes agregar más con "Entrada".',
                                  maxLineas: 6,
                                ),
                              ),
                          ],
                          CampoCompleto(
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Producto activo'),
                              subtitle: const Text(
                                'Desactívalo si ya no lo manejas (se conserva su historial)',
                              ),
                              value: _activo,
                              onChanged: (v) => setState(() => _activo = v),
                            ),
                          ),
                          CampoCompleto(
                            FilledButton.icon(
                              onPressed: _guardando ? null : _guardar,
                              icon: const Icon(Icons.save),
                              label: Text(
                                _guardando ? 'Guardando...' : 'Guardar',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
