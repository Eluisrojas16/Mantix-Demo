import 'package:flutter/material.dart';

import 'licencia/licencia_demo.dart';
import 'licencia/demo_expirada_page.dart';
import 'usuarios/cambiar_password_page.dart';
import 'usuarios/login_page.dart';
import 'usuarios/usuario_modelos.dart';
import 'screens/proximos_page.dart';
import 'screens/clientes_page.dart';
import 'inventario/inventario_page.dart';
import 'ventas/ventas_page.dart';
import 'cobranzas/cobranzas_page.dart';
import 'reportes/reportes_page.dart';
import 'usuarios/usuarios_page.dart';
import 'data/base_datos.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  BaseDatos.inicializarPlataforma();
  // Versión DEMO: se comprueba la licencia local antes de correr la app.
  final demo = await verificarDemo();
  runApp(MantixApp(estadoDemo: demo));
}

class MantixApp extends StatelessWidget {
  final EstadoDemo estadoDemo;
  const MantixApp({super.key, required this.estadoDemo});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mantix Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      // La app escucha los cambios de sesión para navegar automáticamente.
      home: ListenableBuilder(
        listenable: Sesion.instancia,
        builder: (context, _) {
          if (estadoDemo.expirada) {
            return const DemoExpiradaPage();
          }
          if (Sesion.instancia.autenticado) {
            return InicioPage(usuario: Sesion.instancia.actual!);
          }
          return LoginPage(estadoDemo: estadoDemo);
        },
      ),
    );
  }
}

/// Estructura principal: menú inferior para moverse entre secciones.
class InicioPage extends StatefulWidget {
  final Usuario usuario;
  const InicioPage({super.key, required this.usuario});

  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  int _indice = 0;

  /// Pestañas visibles según los permisos del usuario activo.
  List<_Tab> get _tabs {
    final u = widget.usuario;
    return [
      if (u.permisoProximos)
        _Tab(icon: Icons.event_repeat, label: 'Próximos',  page: ProximosPage()),
      if (u.permisoClientes)
        _Tab(icon: Icons.people,       label: 'Clientes',  page: ClientesPage()),
      if (u.permisoInventario)
        _Tab(icon: Icons.inventory_2,  label: 'Inventario',page: InventarioPage()),
      if (u.permisoVentas)
        _Tab(icon: Icons.receipt_long, label: 'Ventas',    page: VentasPage()),
      if (u.permisoCobranzas)
        _Tab(icon: Icons.account_balance_wallet_outlined,
             label: 'Cobranzas',    page: CobranzasPage()),
      if (u.permisoReportes || u.permisoAdmin)
        _Tab(icon: Icons.bar_chart, label: 'Reportes', page: ReportesPage(usuario: u)),
      if (u.permisoAdmin)
        _Tab(icon: Icons.manage_accounts, label: 'Usuarios', page: UsuariosPage()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    // Protección para que _indice no quede fuera de rango al cambiar permisos.
    final idx = _indice.clamp(0, tabs.isEmpty ? 0 : tabs.length - 1);

    if (tabs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mantix')),
        body: const Center(child: Text('Sin módulos asignados.\nContacta al administrador.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Mantix DEMO · ${widget.usuario.nombre}'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Cuenta',
            icon: const Icon(Icons.account_circle),
            onSelected: (v) {
              if (v == 'cambiar') {
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => CambiarPasswordPage(
                      usuario: widget.usuario,
                    ),
                  ),
                );
              } else if (v == 'salir') {
                Sesion.instancia.cerrar();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'cambiar',
                child: ListTile(
                  leading: Icon(Icons.lock_reset),
                  title: Text('Cambiar contraseña'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'salir',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Cerrar sesión'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: tabs[idx].page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: [
          for (final t in tabs)
            NavigationDestination(icon: Icon(t.icon), label: t.label),
        ],
      ),
    );
  }
}

class _Tab {
  final IconData icon;
  final String label;
  final Widget page;
  const _Tab({required this.icon, required this.label, required this.page});
}
