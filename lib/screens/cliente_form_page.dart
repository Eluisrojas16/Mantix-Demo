import 'package:flutter/material.dart';

import '../data/base_datos.dart';
import '../models/cliente.dart';

/// Formulario para crear o editar un cliente (consumidor final o empresa).
class ClienteFormPage extends StatefulWidget {
  final Cliente? cliente;
  const ClienteFormPage({super.key, this.cliente});

  @override
  State<ClienteFormPage> createState() => _ClienteFormPageState();
}

class _ClienteFormPageState extends State<ClienteFormPage> {
  final _formKey = GlobalKey<FormState>();
  late String _tipo = widget.cliente?.tipoCliente ?? 'consumidor';
  late final _nombre =
      TextEditingController(text: widget.cliente?.nombreApellido);
  late final _cedula = TextEditingController(text: widget.cliente?.cedula);
  late final _rnc = TextEditingController(text: widget.cliente?.rnc);
  late final _contacto = TextEditingController(text: widget.cliente?.contacto);
  late final _telefono = TextEditingController(text: widget.cliente?.telefono);
  late final _direccion =
      TextEditingController(text: widget.cliente?.direccion);
  late final _notas = TextEditingController(text: widget.cliente?.notas);
  bool _guardando = false;

  bool get _esEmpresa => _tipo == 'empresa';

  @override
  void dispose() {
    _nombre.dispose();
    _cedula.dispose();
    _rnc.dispose();
    _contacto.dispose();
    _telefono.dispose();
    _direccion.dispose();
    _notas.dispose();
    super.dispose();
  }

  String? _vacioANulo(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  String _soloDigitos(String s) => s.replaceAll(RegExp(r'\D'), '');

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final cliente = Cliente(
      id: widget.cliente?.id,
      tipoCliente: _tipo,
      nombreApellido: _nombre.text.trim(),
      // Cada tipo guarda solo sus propios datos fiscales.
      cedula: _esEmpresa ? null : _vacioANulo(_soloDigitos(_cedula.text)),
      rnc: _esEmpresa ? _vacioANulo(_soloDigitos(_rnc.text)) : null,
      contacto: _esEmpresa ? _vacioANulo(_contacto.text) : null,
      telefono: _vacioANulo(_telefono.text),
      direccion: _vacioANulo(_direccion.text),
      notas: _vacioANulo(_notas.text),
    );

    try {
      await BaseDatos.instancia.guardarCliente(cliente);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      final texto = e.toString();
      String mensaje;
      if (texto.contains('UNIQUE') && texto.contains('rnc')) {
        mensaje = 'Ya existe una empresa con ese RNC.';
      } else if (texto.contains('UNIQUE')) {
        mensaje = 'Ya existe un cliente con esa cédula.';
      } else {
        mensaje = 'No se pudo guardar: $e';
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final esNuevo = widget.cliente == null;
    return Scaffold(
      appBar: AppBar(title: Text(esNuevo ? 'Nuevo cliente' : 'Editar cliente')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'consumidor',
                      label: Text('Consumidor final'),
                      icon: Icon(Icons.person),
                    ),
                    ButtonSegment(
                      value: 'empresa',
                      label: Text('Empresa'),
                      icon: Icon(Icons.business),
                    ),
                  ],
                  selected: {_tipo},
                  onSelectionChanged: (s) => setState(() => _tipo = s.first),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nombre,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: _esEmpresa
                        ? 'Nombre de la empresa *'
                        : 'Nombre y apellido *',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? (_esEmpresa
                          ? 'El nombre de la empresa es obligatorio'
                          : 'El nombre es obligatorio')
                      : null,
                ),
                const SizedBox(height: 16),
                if (_esEmpresa) ...[
                  TextFormField(
                    controller: _rnc,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'RNC *',
                      helperText: '9 dígitos (11 si es persona física), con o sin guiones',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final d = _soloDigitos(v ?? '');
                      if (d.isEmpty) return 'El RNC es obligatorio';
                      return (d.length == 9 || d.length == 11)
                          ? null
                          : 'El RNC debe tener 9 u 11 dígitos';
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contacto,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Persona de contacto',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ] else
                  TextFormField(
                    controller: _cedula,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Cédula de identidad',
                      helperText: '11 dígitos, con o sin guiones',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final d = _soloDigitos(v ?? '');
                      if (d.isEmpty) return null;
                      return d.length == 11
                          ? null
                          : 'La cédula debe tener 11 dígitos';
                    },
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _telefono,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _direccion,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Dirección',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notas,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notas',
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
      ),
    );
  }
}
