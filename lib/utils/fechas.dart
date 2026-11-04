import 'package:flutter/material.dart';

/// Las fechas se guardan como texto AAAA-MM-DD (sin hora, sin zona horaria).
String aIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime? deIso(String? s) => s == null ? null : DateTime.tryParse(s);

/// Hoy, a las 00:00 (el reloj del dispositivo solo se usa para comparar).
DateTime hoySinHora() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// 2026-10-25 -> 25/10/2026
String formatoFecha(String? iso) {
  final d = deIso(iso);
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}

/// Días desde hoy hasta la fecha. Negativo = ya pasó. Null si no hay fecha.
int? diasHasta(String? iso) {
  final d = deIso(iso);
  if (d == null) return null;
  final h = hoySinHora();
  return DateTime.utc(d.year, d.month, d.day)
      .difference(DateTime.utc(h.year, h.month, h.day))
      .inDays;
}

/// Etiqueta de color según qué tan cerca (o pasada) está la fecha.
Widget? chipVencimiento(String? iso) {
  final dias = diasHasta(iso);
  if (dias == null) return null;
  if (dias < 0) {
    return Chip(
      label: Text(dias == -1 ? 'Vencido hace 1 día' : 'Vencido hace ${-dias} días'),
      backgroundColor: const Color(0xFFFFCDD2),
    );
  }
  if (dias == 0) {
    return const Chip(
      label: Text('Hoy'),
      backgroundColor: Color(0xFFFFE0B2),
    );
  }
  return Chip(
    label: Text(dias == 1 ? 'Mañana' : 'En $dias días'),
    backgroundColor: dias <= 7 ? const Color(0xFFFFE0B2) : null,
  );
}
