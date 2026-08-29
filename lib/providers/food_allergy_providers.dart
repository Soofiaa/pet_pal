import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/food_allergy.dart';
import 'package:pet_pal/providers/database_providers.dart';
import 'package:pet_pal/repositories/food_allergy_repository.dart';

final foodAllergyRepositoryProvider = Provider<FoodAllergyRepository>((ref) {
  return FoodAllergyRepository(ref.watch(databaseHelperProvider));
});

/// Reemplaza los antiguos campos _foodAllergies/_isLoading manejados a
/// mano en food_allergy_screen.dart. Es la única puerta de escritura real
/// para Alergias Alimentarias (ver el comentario de FoodAllergyRepository).
/// A diferencia de Deworming/Vaccination/Document/Note/Appointment, no
/// orquesta nada más que los datos: sin archivos, sin ReminderScheduler.
final foodAllergiesProvider = AsyncNotifierProvider.family<
    FoodAllergiesNotifier, List<FoodAllergy>, String>(
  FoodAllergiesNotifier.new,
);

class FoodAllergiesNotifier
    extends FamilyAsyncNotifier<List<FoodAllergy>, String> {
  @override
  Future<List<FoodAllergy>> build(String petId) async {
    final repository = ref.watch(foodAllergyRepositoryProvider);
    return repository.getFoodAllergiesForPet(petId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build(arg));
  }

  Future<void> addFoodAllergy(FoodAllergy foodAllergy) async {
    await ref.read(foodAllergyRepositoryProvider).insertFoodAllergy(foodAllergy);
    await refresh();
  }

  Future<void> updateFoodAllergy(FoodAllergy foodAllergy) async {
    await ref.read(foodAllergyRepositoryProvider).updateFoodAllergy(foodAllergy);
    await refresh();
  }

  Future<void> deleteFoodAllergy(int id) async {
    await ref.read(foodAllergyRepositoryProvider).deleteFoodAllergy(id);
    await refresh();
  }
}
