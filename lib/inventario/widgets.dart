import 'package:flutter/material.dart';

/// Color del estado de stock (null = color normal).
Color? colorEstadoStock(String estado) {
  switch (estado) {
    case 'agotado':
      return Colors.red;
    case 'bajo':
      return Colors.orange;
    default:
      return null;
  }
}

/// Texto corto del estado de stock (null = no se muestra nada).
String? textoEstadoStock(String estado) {
  switch (estado) {
    case 'agotado':
      return 'Agotado';
    case 'bajo':
      return 'Stock bajo';
    default:
      return null;
  }
}
