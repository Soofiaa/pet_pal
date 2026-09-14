// Pruebas de LocationEntriesNotifier (locationEntriesProvider): agregar,
// editar y eliminar contra un repository fake en memoria -la base de datos
// real ya está cubierta en test/repositories/location_entry_repository_test.dart-.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pet_pal/models/location_entry.dart';
import 'package:pet_pal/providers/location_entry_providers.dart';
import 'package:pet_pal/repositories/location_entry_repository.dart';

class _FakeLocationEntryRepository implements LocationEntryRepository {
  _FakeLocationEntryRepository(this.entries);

  final List<LocationEntry> entries;

  @override
  Future<List<LocationEntry>> getEntries() async {
    final sorted = [...entries]..sort((a, b) => a.name.compareTo(b.name));
    return sorted;
  }

  @override
  Future<void> insertEntry(LocationEntry entry) async {
    entries.add(entry);
  }

  @override
  Future<void> updateEntry(LocationEntry entry) async {
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index != -1) entries[index] = entry;
  }

  @override
  Future<void> deleteEntry(String id) async {
    entries.removeWhere((e) => e.id == id);
  }
}

void main() {
  ProviderContainer buildContainer(List<LocationEntry> entries) {
    final container = ProviderContainer(
      overrides: [
        locationEntryRepositoryProvider.overrideWithValue(
          _FakeLocationEntryRepository(entries),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('locationEntriesProvider (LocationEntriesNotifier)', () {
    test('carga las entradas existentes ordenadas por nombre', () async {
      final entries = [
        LocationEntry(id: 'e1', name: 'Zoológico', mapsUrl: ''),
        LocationEntry(id: 'e2', name: 'Alameda', mapsUrl: ''),
      ];
      final container = buildContainer(entries);

      final result = await container.read(locationEntriesProvider.future);

      expect(result.map((e) => e.name).toList(), ['Alameda', 'Zoológico']);
    });

    test('addEntry agrega la entrada y refresca el estado', () async {
      final entries = <LocationEntry>[];
      final container = buildContainer(entries);
      await container.read(locationEntriesProvider.future);

      await container.read(locationEntriesProvider.notifier).addEntry(
            LocationEntry(id: 'e1', name: 'Veterinaria Central', mapsUrl: 'https://x'),
          );

      final result = container.read(locationEntriesProvider).value;
      expect(result, hasLength(1));
      expect(result!.single.name, 'Veterinaria Central');
    });

    test('updateEntry edita la entrada y refresca el estado', () async {
      final entries = [LocationEntry(id: 'e1', name: 'Nombre Viejo', mapsUrl: 'https://old')];
      final container = buildContainer(entries);
      await container.read(locationEntriesProvider.future);

      await container.read(locationEntriesProvider.notifier).updateEntry(
            entries.first.copyWith(name: 'Nombre Nuevo', mapsUrl: 'https://new'),
          );

      final result = container.read(locationEntriesProvider).value;
      expect(result!.single.name, 'Nombre Nuevo');
      expect(result.single.mapsUrl, 'https://new');
    });

    test('deleteEntry elimina la entrada y refresca el estado', () async {
      final entries = [LocationEntry(id: 'e1', name: 'Lugar A', mapsUrl: '')];
      final container = buildContainer(entries);
      await container.read(locationEntriesProvider.future);

      await container.read(locationEntriesProvider.notifier).deleteEntry('e1');

      final result = container.read(locationEntriesProvider).value;
      expect(result, isEmpty);
    });
  });
}
