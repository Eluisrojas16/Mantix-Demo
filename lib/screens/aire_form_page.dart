import 'package:flutter/material.dart';

import '../data/aires_db.dart';
import '../data/base_datos.dart';
import '../data/mantenimientos_db.dart';
import '../models/aire.dart';
import '../models/mantenimiento.dart';
import '../utils/fechas.dart';

const _tipos = ['Split', 'Ventana', 'Cassette', 'Piso techo', 'Portátil', 'Otro'];

/// Formulario para crear o editar un aire acondicionado de un cliente.
class AireFormPage extends StatefulWidget {
  final int clienteId;
  final Aire? aire;
  const AireFormPage({super.key, required this.clienteId, this.aire});

  @override
  State<AireFormPage> createState() => _AireFormPageState();
}

class _AireFormPageState extends State<AireFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _posicion = TextEditingController(text: widget.aire?.posicion);
  late final _marca = TextEditingController(text: widget.aire?.marca);
  late final _modelo = TextEditingController(text: widget.aire?.modelo);
  late final _btu =
      TextEditingController(text: widget.aire?.btu?.toString() ?? '');
  late final _serial = TextEditingController(text: widget.aire?.serial);
  late final _periodicidad = TextEditingController(
    text: (widget.aire?.periodicidadMeses ?? 6).toString(),
  );
  late String? _tipo =
      _tipos.contains(widget.aire?.tipo) ? widget.aire?.tipo : null;
  late bool _activo = widget.aire?.activo ?? true;
  DateTime? _ultimoMantenimiento; // solo al crear un aire nuevo
  bool _guardando = false;

  @override
  void dispose() {
    _posicion.dispose();
    _marca.dispose();
    _modelo.dispose();
    _btu.dispose();
    _serial.dispose();
    _periodicidad.dispose();
    super.dispose();
  }

  String? _vacioANulo(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _elegirUltimoMantenimiento() async {
    final hoy = hoySinHora();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _ultimoMantenimiento ?? hoy,
      firstDate: DateTime(2000),
      lastDate: hoy,
    );
    if (elegida != null && mounted) {
      setState(() => _ultimoMantenimiento = elegida);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final aire = Aire(
      id: widget.aire?.id,
      clienteId: widget.clienteId,
      posicion: _vacioANulo(_posicion.text),
      marca: _vacioANulo(_marca.text),
      modelo: _vacioANulo(_modelo.text),
      tipo: _tipo,
      btu: int.tryParse(_btu.text.trim()),
      serial: _vacioANulo(_serial.text),
      periodicidadMeses: int.parse(_periodicidad.text.trim()),
      activo: _activo,
    );

    try {
      final aireId = await BaseDatos.instancia.guardarAire(aire);

      // Si es un aire nuevo y se indicó cuándo fue su último mantenimiento,
      // se crea ese registro: desde esa fecha empieza a contar el reloj.
      if (widget.aire == null && _ultimoMantenimiento != null) {
        await BaseDatos.instancia.guardarMantenimiento(
          Mantenimiento(
            aireId: aireId,
            fecha: aIso(_ultimoMantenimiento!),
            tipo: 'preventivo',
            estado: 'realizado',
            trabajoRealizado: 'Mantenimiento anterior (registrado al crear el aire)',
          ),
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final esNuevo = widget.aire == null;
    return Scaffold(
      appBar: AppBar(title: Text(esNuevo ? 'Nuevo aire' : 'Editar aire')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _posicion,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Posición / ubicación *',
                    helperText: 'Ej. Sala, Cuarto principal, Oficina',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Indica dónde está el aire'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _marca,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Marca',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _modelo,
                  decoration: const InputDecoration(
                    labelText: 'Modelo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _tipo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final t in _tipos)
                      DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: (v) => setState(() => _tipo = v),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _btu,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Capacidad (BTU)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null;
                    return int.tryParse(t) == null ? 'Solo números' : null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _serial,
                  decoration: const InputDecoration(
                    labelText: 'Serial',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _periodicidad,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Mantenimiento cada (meses) *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n < 1 || n > 60) {
                      return 'Un número entre 1 y 60';
                    }
                    return null;
                  },
                ),
                if (esNuevo) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _elegirUltimoMantenimiento,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Fecha del último mantenimiento (opcional)',
                        helperText:
                            'Desde esta fecha empieza a contar el próximo mantenimiento',
                        border: const OutlineInputBorder(),
                        suffixIcon: _ultimoMantenimiento == null
                            ? const Icon(Icons.calendar_today)
                            : IconButton(
                                tooltip: 'Quitar fecha',
                                icon: const Icon(Icons.clear),
                                onPressed: () => setState(
                                    () => _ultimoMantenimiento = null),
                              ),
                      ),
                      child: Text(
                        _ultimoMantenimiento == null
                            ? 'Sin fecha'
                            : formatoFecha(aIso(_ultimoMantenimiento!)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Equipo activo'),
                  subtitle: const Text(
                    'Desactívalo si el aire ya no está en servicio',
                  ),
                  value: _activo,
                  onChanged: (v) => setState(() => _activo = v),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _guardando ? null : _guardar,
                  icon: const Icon(Icons.save),
                  label: Text(_guardando ? 'Guardando...' : 'Guardar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
