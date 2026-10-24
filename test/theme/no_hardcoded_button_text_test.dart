// Los botones destructivos/confirmar con texto blanco fijo sobre
// colorScheme.error pierden contraste en modo oscuro (el error es un rojo
// claro). El texto debe heredar foregroundColor (onError del tema).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ningún botón de diálogo fuerza texto blanco fijo', () {
    final pattern = RegExp(
      r"Text\('(Eliminar|Restaurar)',\s*style:\s*(const\s+)?TextStyle\(color:\s*Colors\.white\)",
    );
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        if (pattern.hasMatch(entity.readAsStringSync())) {
          offenders.add(entity.path);
        }
      }
    }

    expect(offenders, isEmpty);
  });
}
