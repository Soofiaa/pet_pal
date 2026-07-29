import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/weight_record.dart';
import 'package:pet_pal/providers/database_providers.dart';
import 'package:pet_pal/repositories/weight_record_repository.dart';

final weightRecordRepositoryProvider = Provider<WeightRecordRepository>((ref) {
  return WeightRecordRepository(ref.watch(databaseHelperProvider));
});

/// Reemplaza los antiguos campos _weightRecords/_isLoading manejados a
/// mano con setState en weight_record_screen.dart. Un provider por
/// mascota (family), así cada pantalla observa solo los registros de la
/// mascota que le corresponde.
final weightRecordsProvider = AsyncNotifierProvider.family<
    WeightRecordsNotifier, List<WeightRecord>, String>(
  WeightRecordsNotifier.new,
);

class WeightRecordsNotifier
    extends FamilyAsyncNotifier<List<WeightRecord>, String> {
  @override
  Future<List<WeightRecord>> build(String petId) async {
    final repository = ref.watch(weightRecordRepositoryProvider);
    final records = await repository.getWeightRecordsForPet(petId);
    records.sort((a, b) => a.date.compareTo(b.date));
    return records;
  }

  /// Vuelve a cargar los registros de esta mascota. Se llama después de
  /// agregar, editar o eliminar un registro.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build(arg));
  }
}
