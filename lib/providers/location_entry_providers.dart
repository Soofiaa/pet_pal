import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/location_entry.dart';
import 'package:pet_pal/providers/database_providers.dart';
import 'package:pet_pal/repositories/location_entry_repository.dart';

final locationEntryRepositoryProvider = Provider<LocationEntryRepository>((ref) {
  return LocationEntryRepository(ref.watch(databaseHelperProvider));
});

/// Catálogo de lugares reusable entre citas de todas las mascotas (ver
/// add_edit_appointment_screen.dart). Elegir un lugar del catálogo copia su
/// name/mapsUrl a la cita en el momento de guardar -no una referencia-, así
/// que editar o borrar una entrada acá con este notifier nunca reescribe
/// citas ya guardadas.
final locationEntriesProvider =
    AsyncNotifierProvider<LocationEntriesNotifier, List<LocationEntry>>(
  LocationEntriesNotifier.new,
);

class LocationEntriesNotifier extends AsyncNotifier<List<LocationEntry>> {
  @override
  Future<List<LocationEntry>> build() async {
    return ref.watch(locationEntryRepositoryProvider).getEntries();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> addEntry(LocationEntry entry) async {
    await ref.read(locationEntryRepositoryProvider).insertEntry(entry);
    await refresh();
  }

  Future<void> updateEntry(LocationEntry entry) async {
    await ref.read(locationEntryRepositoryProvider).updateEntry(entry);
    await refresh();
  }

  Future<void> deleteEntry(String id) async {
    await ref.read(locationEntryRepositoryProvider).deleteEntry(id);
    await refresh();
  }
}
