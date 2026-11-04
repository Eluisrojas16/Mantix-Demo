import 'package:flutter/material.dart';

import '../data/base_datos.dart';
import '../inventario/dialogos.dart';
import 'usuario_modelos.dart';
import 'usuarios_db.dart';

/// Gestión de Usuarios y Permisos granulares (Cotejos por área).
class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key});

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  late Future<List<Usuario>> _futuro = BaseDatos.instancia.listarUsuarios();

  void _recargar() {
    setState(() {
      _futuro = BaseDatos.instancia.listarUsuarios();
    });
  }

  Future<void> _abrirFormulario([Usuario? u]) async {
    final nombreCtrl = TextEditingController(text: u?.nombre ?? '');
    final usuarioCtrl = TextEditingController(text: u?.usuario ?? '');
    final claveCtrl = TextEditingController(text: u?.clave ?? '');
    var rolBase = u?.rolBase ?? 'personalizado';
    var activo = u?.activo ?? true;

    // Permisos por cotejo
    var pProximos = u?.permisoProximos ?? true;
    var pClientes = u?.permisoClientes ?? true;
    var pInventario = u?.permisoInventario ?? false;
    var pVentas = u?.permisoVentas ?? false;
    var pCobranzas = u?.permisoCobranzas ?? false;
    var pReportes = u?.permisoReportes ?? false;
    var pAdmin = u?.permisoAdmin ?? false;

    void aplicarPlantilla(String rol, void Function(void Function()) setModalState) {
      setModalState(() {
        rolBase = rol;
        switch (rol) {
          case 'admin':
            pProximos = true;
            pClientes = true;
            pInventario = true;
            pVentas = true;
            pCobranzas = true;
            pReportes = true;
            pAdmin = true;
            break;
          case 'cobrador':
            pProximos = false;
            pClientes = true;
            pInventario = false;
            pVentas = false;
            pCobranzas = true;
            pReportes = true;
            pAdmin = false;
            break;
          case 'facturador':
            pProximos = false;
            pClientes = true;
            pInventario = false;
            pVentas = true;
            pCobranzas = false;
            pReportes = false;
            pAdmin = false;
            break;
          case 'inventario':
            pProximos = false;
            pClientes = false;
            pInventario = true;
            pVentas = false;
            pCobranzas = false;
            pReportes = false;
            pAdmin = false;
            break;
          case 'personalizado':
          default:
            break;
        }
      });
    }

    final guardado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(u == null ? 'Nuevo Usuario' : 'Editar Usuario'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre y Apellido *',
                      hintText: 'Ej. Juan Pérez',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: usuarioCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de usuario *',
                            hintText: 'Ej. jperez',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: claveCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña / PIN *',
                            hintText: 'Ej. 1234',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Selector de Plantilla rápida
                  DropdownButtonFormField<String>(
                    value: rolBase,
                    decoration: const InputDecoration(
                      labelText: 'Plantilla de Rol (Rápida)',
                      helperText: 'Aplica permisos recomendados, luego puedes ajustarlos abajo con los cotejos.',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final entry in rolesPredefinidos.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) aplicarPlantilla(v, setModalState);
                    },
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Cotejo de áreas permitidas para este usuario:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(ctx).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),

                  CheckboxListTile(
                    dense: true,
                    title: const Text('Próximos mantenimientos (Servicios)'),
                    value: pProximos,
                    onChanged: (v) => setModalState(() {
                      pProximos = v ?? false;
                      rolBase = 'personalizado';
                    }),
                  ),
                  CheckboxListTile(
                    dense: true,
                    title: const Text('Clientes (Directorio y equipos)'),
                    value: pClientes,
                    onChanged: (v) => setModalState(() {
                      pClientes = v ?? false;
                      rolBase = 'personalizado';
                    }),
                  ),
                  CheckboxListTile(
                    dense: true,
                    title: const Text('Inventario (Almacén, seriales y entradas/salidas)'),
                    value: pInventario,
                    onChanged: (v) => setModalState(() {
                      pInventario = v ?? false;
                      rolBase = 'personalizado';
                    }),
                  ),
                  CheckboxListTile(
                    dense: true,
                    title: const Text('Ventas (Cotizaciones y Facturación)'),
                    value: pVentas,
                    onChanged: (v) => setModalState(() {
                      pVentas = v ?? false;
                      rolBase = 'personalizado';
                    }),
                  ),
                  CheckboxListTile(
                    dense: true,
                    title: const Text('Cobranzas (Cuentas por cobrar y abonos)'),
                    value: pCobranzas,
                    onChanged: (v) => setModalState(() {
                      pCobranzas = v ?? false;
                      rolBase = 'personalizado';
                    }),
                  ),
                  CheckboxListTile(
                    dense: true,
                    title: const Text('Reportes y Cuadre de Caja'),
                    value: pReportes,
                    onChanged: (v) => setModalState(() {
                      pReportes = v ?? false;
                      rolBase = 'personalizado';
                    }),
                  ),
                  CheckboxListTile(
                    dense: true,
                    title: const Text('Administración (Usuarios, anulación y ajustes)'),
                    value: pAdmin,
                    onChanged: (v) => setModalState(() {
                      pAdmin = v ?? false;
                      rolBase = 'personalizado';
                    }),
                  ),

                  if (u != null && u.id != 1) ...[
                    const Divider(height: 16),
                    SwitchListTile(
                      dense: true,
                      title: const Text('Usuario activo'),
                      subtitle: const Text('Si se desactiva, no podrá iniciar sesión.'),
                      value: activo,
                      onChanged: (v) => setModalState(() => activo = v),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final nom = nombreCtrl.text.trim();
                final usu = usuarioCtrl.text.trim();
                final cla = claveCtrl.text.trim();
                if (nom.isEmpty || usu.isEmpty || cla.isEmpty) {
                  aviso(ctx, 'Nombre, usuario y clave son obligatorios.');
                  return;
                }

                final nuevo = Usuario(
                  id: u?.id,
                  nombre: nom,
                  usuario: usu,
                  clave: cla,
                  rolBase: rolBase,
                  permisoProximos: pProximos,
                  permisoClientes: pClientes,
                  permisoInventario: pInventario,
                  permisoVentas: pVentas,
                  permisoCobranzas: pCobranzas,
                  permisoReportes: pReportes,
                  permisoAdmin: pAdmin,
                  activo: activo,
                );

                try {
                  await BaseDatos.instancia.guardarUsuario(nuevo);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) {
                    aviso(ctx, e.toString().contains('UNIQUE')
                        ? 'Ese nombre de usuario ya está en uso.'
                        : 'Error al guardar: $e');
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (guardado == true && mounted) {
      _recargar();
    }
  }

  Future<void> _eliminar(Usuario u) async {
    if (u.id == 1) {
      aviso(context, 'No se puede eliminar el Administrador principal.');
      return;
    }
    final ok = await confirmar(
      context,
      'Eliminar usuario',
      '¿Seguro que deseas eliminar al usuario "${u.nombre}" (${u.usuario})?',
      textoConfirmar: 'Eliminar',
    );
    if (!ok || !mounted) return;
    try {
      await BaseDatos.instancia.eliminarUsuario(u.id!);
      _recargar();
    } catch (e) {
      if (mounted) aviso(context, 'No se pudo eliminar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios y Roles'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo usuario'),
      ),
      body: FutureBuilder<List<Usuario>>(
        future: _futuro,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final usuarios = snap.data ?? [];
          if (usuarios.isEmpty) {
            return const Center(child: Text('No hay usuarios registrados.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: usuarios.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final u = usuarios[i];
              final permisos = <String>[
                if (u.permisoProximos) 'Próximos',
                if (u.permisoClientes) 'Clientes',
                if (u.permisoInventario) 'Inventario',
                if (u.permisoVentas) 'Ventas',
                if (u.permisoCobranzas) 'Cobranzas',
                if (u.permisoReportes) 'Reportes',
                if (u.permisoAdmin) 'Admin',
              ];

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: u.esAdmin
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Colors.grey.shade200,
                    child: Icon(
                      u.esAdmin ? Icons.admin_panel_settings : Icons.person,
                      color: u.esAdmin
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade700,
                    ),
                  ),
                  title: Text(
                    '${u.nombre} (@${u.usuario})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rol base: ${rolesPredefinidos[u.rolBase] ?? u.rolBase}'
                        '${u.activo ? '' : ' · (Inactivo)'}',
                        style: TextStyle(
                          color: u.activo ? Colors.grey.shade700 : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final p in permisos)
                            Chip(
                              label: Text(p, style: const TextStyle(fontSize: 10)),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (op) {
                      if (op == 'editar') _abrirFormulario(u);
                      if (op == 'eliminar') _eliminar(u);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'editar', child: Text('Editar')),
                      if (u.id != 1)
                        const PopupMenuItem(
                          value: 'eliminar',
                          child: Text('Eliminar', style: TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
