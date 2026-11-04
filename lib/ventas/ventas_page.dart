import 'package:flutter/material.dart';

import 'cotizaciones_tab.dart';
import 'facturas_tab.dart';
import 'negocio_page.dart';

/// Sección de ventas: cotizaciones y facturas.
class VentasPage extends StatelessWidget {
  const VentasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ventas'),
          actions: [
            IconButton(
              tooltip: 'Datos del negocio',
              icon: const Icon(Icons.storefront_outlined),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const NegocioPage()),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Cotizaciones'),
              Tab(text: 'Facturas'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [CotizacionesTab(), FacturasTab()],
        ),
      ),
    );
  }
}
