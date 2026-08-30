import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/food_record.dart';
import 'package:pet_pal/providers/database_providers.dart';
import 'package:pet_pal/repositories/food_record_repository.dart';

final foodRecordRepositoryProvider = Provider<FoodRecordRepository>((ref) {
  return FoodRecordRepository(ref.watch(databaseHelperProvider));
});

/// Única puerta de escritura real para Historial de Alimentos (ver el
/// comentario de FoodRecordRepository). Igual que FoodAllergiesNotifier, no
/// orquesta nada más que los datos: sin archivos, sin ReminderScheduler.
final foodRecordsProvider = AsyncNotifierProvider.family<
    FoodRecordsNotifier, List<FoodRecord>, String>(
  FoodRecordsNotifier.new,
);

class FoodRecordsNotifier
    extends FamilyAsyncNotifier<List<FoodRecord>, String> {
  @override
  Future<List<FoodRecord>> build(String petId) async {
    final repository = ref.watch(foodRecordRepositoryProvider);
    return repository.getFoodRecordsForPet(petId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build(arg));
  }

  Future<void> addFoodRecord(FoodRecord foodRecord) async {
    await ref.read(foodRecordRepositoryProvider).insertFoodRecord(foodRecord);
    await refresh();
  }

  Future<void> updateFoodRecord(FoodRecord foodRecord) async {
    await ref.read(foodRecordRepositoryProvider).updateFoodRecord(foodRecord);
    await refresh();
  }

  Future<void> deleteFoodRecord(int id) async {
    await ref.read(foodRecordRepositoryProvider).deleteFoodRecord(id);
    await refresh();
  }
}
