// Pruebas de FoodAllergiesNotifier: la orquestación es la más simple de
// las cuatro migraciones -sin archivos, sin ReminderScheduler-, así que a
// diferencia de deworming_providers_test.dart/appointment_providers_test.dart
// no hace falta mockear el canal de flutter_local_notifications. Mismo
// patrón que weight_record_providers_test.dart: repository fake en
// memoria + ProviderContainer.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pet_pal/models/food_allergy.dart';
import 'package:pet_pal/providers/food_allergy_providers.dart';
import 'package:pet_pal/repositories/food_allergy_repository.dart';

class _FakeFoodAllergyRepository implements FoodAllergyRepository {
  _FakeFoodAllergyRepository(this.records);

  final List<FoodAllergy> records;
  int _nextId = 1;

  @override
  Future<List<FoodAllergy>> getFoodAllergiesForPet(String petId) async {
    return records.where((r) => r.petId == petId).toList();
  }

  @override
  Future<int> insertFoodAllergy(FoodAllergy foodAllergy) async {
    final int id = _nextId++;
    records.add(foodAllergy.copyWith(id: id));
    return id;
  }

  @override
  Future<void> updateFoodAllergy(FoodAllergy foodAllergy) async {
    final index = records.indexWhere((r) => r.id == foodAllergy.id);
    if (index != -1) records[index] = foodAllergy;
  }

  @override
  Future<void> deleteFoodAllergy(int id) async {
    records.removeWhere((r) => r.id == id);
  }
}

void main() {
  ProviderContainer buildContainer(List<FoodAllergy> records) {
    final container = ProviderContainer(
      overrides: [
        foodAllergyRepositoryProvider.overrideWithValue(
          _FakeFoodAllergyRepository(records),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('FoodAllergiesNotifier', () {
    test('build carga las alergias de la mascota indicada', () async {
      final records = <FoodAllergy>[
        FoodAllergy(id: 1, petId: 'pet-1', food: 'Pollo', dateRecorded: DateTime(2026, 1, 1)),
        FoodAllergy(id: 2, petId: 'pet-2', food: 'Res', dateRecorded: DateTime(2026, 1, 1)),
      ];
      final container = buildContainer(records);

      final result = await container.read(foodAllergiesProvider('pet-1').future);

      expect(result, hasLength(1));
      expect(result.single.food, 'Pollo');
    });

    test('addFoodAllergy persiste el registro y refresca el estado', () async {
      final records = <FoodAllergy>[];
      final container = buildContainer(records);

      await container.read(foodAllergiesProvider('pet-1').notifier).addFoodAllergy(
            FoodAllergy(petId: 'pet-1', food: 'Pollo', dateRecorded: DateTime(2026, 1, 1)),
          );

      expect(records, hasLength(1));
      expect(records.single.food, 'Pollo');

      final state = await container.read(foodAllergiesProvider('pet-1').future);
      expect(state, hasLength(1));
    });

    test('addFoodAllergy con dos registros no colisiona ni pierde ninguno', () async {
      final records = <FoodAllergy>[];
      final container = buildContainer(records);
      final notifier = container.read(foodAllergiesProvider('pet-1').notifier);

      await notifier.addFoodAllergy(
        FoodAllergy(petId: 'pet-1', food: 'Pollo', dateRecorded: DateTime(2026, 1, 1)),
      );
      await notifier.addFoodAllergy(
        FoodAllergy(petId: 'pet-1', food: 'Trigo', dateRecorded: DateTime(2026, 2, 1)),
      );

      final state = await container.read(foodAllergiesProvider('pet-1').future);
      expect(state.map((a) => a.food).toSet(), {'Pollo', 'Trigo'});
    });

    test('updateFoodAllergy actualiza el registro existente y refresca el estado', () async {
      final original = FoodAllergy(
        id: 1,
        petId: 'pet-1',
        food: 'Pollo',
        dateRecorded: DateTime(2026, 1, 1),
      );
      final records = <FoodAllergy>[original];
      final container = buildContainer(records);

      await container
          .read(foodAllergiesProvider('pet-1').notifier)
          .updateFoodAllergy(original.copyWith(food: 'Pollo y derivados'));

      expect(records.single.food, 'Pollo y derivados');
      final state = await container.read(foodAllergiesProvider('pet-1').future);
      expect(state.single.food, 'Pollo y derivados');
    });

    test('deleteFoodAllergy elimina el registro y refresca el estado', () async {
      final original = FoodAllergy(
        id: 1,
        petId: 'pet-1',
        food: 'Pollo',
        dateRecorded: DateTime(2026, 1, 1),
      );
      final records = <FoodAllergy>[original];
      final container = buildContainer(records);

      await container.read(foodAllergiesProvider('pet-1').notifier).deleteFoodAllergy(1);

      expect(records, isEmpty);
      final state = await container.read(foodAllergiesProvider('pet-1').future);
      expect(state, isEmpty);
    });

    test('refresh() vuelve a consultar el repository', () async {
      final records = <FoodAllergy>[
        FoodAllergy(id: 1, petId: 'pet-1', food: 'Pollo', dateRecorded: DateTime(2026, 1, 1)),
      ];
      final container = buildContainer(records);
      await container.read(foodAllergiesProvider('pet-1').future);

      // Cambio hecho "por afuera" del notifier, simulando otra fuente de
      // escritura -acá solo para probar que refresh() vuelve a leer, no
      // que sirve de excusa para escribir por afuera del notifier en la app real.
      records.add(FoodAllergy(id: 2, petId: 'pet-1', food: 'Trigo', dateRecorded: DateTime(2026, 2, 1)));

      await container.read(foodAllergiesProvider('pet-1').notifier).refresh();

      final state = await container.read(foodAllergiesProvider('pet-1').future);
      expect(state, hasLength(2));
    });
  });
}
