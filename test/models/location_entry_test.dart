// Pruebas de LocationEntry: creación (id autogenerado) y serialización
// round-trip (toJson/fromJson), usada por DatabaseHelper para leer/escribir
// la tabla location_entries.
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_pal/models/location_entry.dart';

void main() {
  group('LocationEntry - creación', () {
    test('sin id explícito, genera uno no vacío', () {
      final entry = LocationEntry(name: 'Veterinaria Central', mapsUrl: 'https://maps.app.goo.gl/x');
      expect(entry.id, isNotEmpty);
    });

    test('dos entradas sin id explícito reciben ids distintos', () {
      final a = LocationEntry(name: 'Lugar A', mapsUrl: '');
      final b = LocationEntry(name: 'Lugar B', mapsUrl: '');
      expect(a.id, isNot(b.id));
    });

    test('con id explícito, lo respeta tal cual', () {
      final entry = LocationEntry(id: 'entry-1', name: 'Lugar A', mapsUrl: '');
      expect(entry.id, 'entry-1');
    });
  });

  group('LocationEntry - serialización', () {
    test('toJson/fromJson: round-trip conserva todos los campos', () {
      final original = LocationEntry(
        id: 'entry-1',
        name: 'Veterinaria Central',
        mapsUrl: 'https://maps.app.goo.gl/AbCdEfGh',
      );

      final restored = LocationEntry.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.mapsUrl, original.mapsUrl);
    });

    test('mapsUrl vacío se conserva tal cual (no se vuelve null)', () {
      final original = LocationEntry(id: 'entry-2', name: 'Lugar sin link', mapsUrl: '');
      final restored = LocationEntry.fromJson(original.toJson());
      expect(restored.mapsUrl, '');
    });
  });

  group('LocationEntry.copyWith', () {
    test('sin argumentos, devuelve una copia idéntica', () {
      final original = LocationEntry(id: 'entry-1', name: 'Lugar A', mapsUrl: 'https://x');
      final copy = original.copyWith();
      expect(copy.id, original.id);
      expect(copy.name, original.name);
      expect(copy.mapsUrl, original.mapsUrl);
    });

    test('reemplaza solo los campos indicados', () {
      final original = LocationEntry(id: 'entry-1', name: 'Lugar A', mapsUrl: 'https://x');
      final copy = original.copyWith(name: 'Lugar A (editado)');
      expect(copy.id, original.id);
      expect(copy.name, 'Lugar A (editado)');
      expect(copy.mapsUrl, original.mapsUrl);
    });
  });
}
