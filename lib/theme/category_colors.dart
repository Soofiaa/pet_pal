import 'package:flutter/material.dart';

/// Colores por categoría de función. Son tonos medios pensados para ícono (no
/// texto): superan 3:1 tanto sobre el fondo claro como sobre el oscuro, así
/// que sirven en ambos temas sin ramificar por brillo.
class CategoryColors {
  const CategoryColors._();

  /// Vacunas, medicación, desparasitación, signos vitales, alergias.
  static const Color health = Color(0xFF0D9488);

  /// Peso, notas, documentos, alimentos.
  static const Color records = Color(0xFF64748B);

  /// Citas y eventos.
  static const Color agenda = Color(0xFFE4572E);
}
