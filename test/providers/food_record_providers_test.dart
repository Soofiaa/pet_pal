// Pruebas de FoodRecordsNotifier: la orquestación es la más simple de las
// migraciones de datos puros -sin archivos, sin ReminderScheduler-, mismo
// patrón que food_allergy_providers_test.dart: repository fake en memoria +
// ProviderContainer.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pet_pal/models/food_record.dart';
import 'package:pet_pal/providers/food_record_providers.dart';
import 'package:pet_pal/repositories/food_record_repository.dart';

class _FakeFoodRecordRepository implements FoodRecordRepository {
  _FakeFoodRecordRepository(this.records);

  final List<FoodRecord> records;
  int _nextId = 1;

  @override
  Future<List<FoodRecord>> getFoodRecordsForPet(String petId) async {
    return records.where((r) => r.petId == petId).toList();
  }

  @override
  Future<int> insertFoodRecord(FoodRecord foodRecord) async {
    final int id = _nextId++;
    records.add(foodRecord.copyWith(id: id));
    return id;
  }

  @override
  Future<void> updateFoodRecord(FoodRecord foodRecord) async {
    final index = records.indexWhere((r) => r.id == foodRecord.id);
    if (index != -1) records[index] = foodRecord;
  }

  @override
  Future<void> deleteFoodRecord(int id) async {
    records.removeWhere((r) => r.id == id);
  }
}

void main() {
  ProviderContainer buildContainer(List<FoodRecord> records) {
    final container = ProviderContainer(
      overrides: [
        foodRecordRepositoryProvider.overrideWithValue(
          _FakeFoodRecordRepository(records),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('FoodRecordsNotifier', () {
    test('build carga los registros de alimento de la mascota indicada', () async {
      final records = <FoodRecord>[
        FoodRecord(id: 1, petId: 'pet-1', foodName: 'Croquetas', startDate: DateTime(2026, 1, 1)),
        FoodRecord(id: 2, petId: 'pet-2', foodName: 'Pollo hervido', startDate: DateTime(2026, 1, 1)),
      ];
      final container = buildContainer(records);

      final result = await container.read(foodRecordsProvider('pet-1').future);

      expect(result, hasLength(1));
      expect(result.single.foodName, 'Croquetas');
    });

    test('addFoodRecord persiste el registro y refresca el estado', () async {
      final records = <FoodRecord>[];
      final container = buildContainer(records);

      await container.read(foodRecordsProvider('pet-1').notifier).addFoodRecord(
            FoodRecord(petId: 'pet-1', foodName: 'Croquetas', startDate: DateTime(2026, 1, 1)),
          );

      expect(records, hasLength(1));
      expect(records.single.foodName, 'Croquetas');

      final state = await container.read(foodRecordsProvider('pet-1').future);
      expect(state, hasLength(1));
    });

    test('addFoodRecord con startDate null persiste el registro igual', () async {
      final records = <FoodRecord>[];
      final container = buildContainer(records);

      await container.read(foodRecordsProvider('pet-1').notifier).addFoodRecord(
            FoodRecord(petId: 'pet-1', foodName: 'Croquetas', startDate: null),
          );

      final state = await container.read(foodRecordsProvider('pet-1').future);
      expect(state, hasLength(1));
      expect(state.single.startDate, isNull);
    });

    test('updateFoodRecord actualiza el registro existente y refresca el estado', () async {
      final original = FoodRecord(
        id: 1,
        petId: 'pet-1',
        foodName: 'Croquetas',
        startDate: DateTime(2026, 1, 1),
      );
      final records = <FoodRecord>[original];
      final container = buildContainer(records);

      await container
          .read(foodRecordsProvider('pet-1').notifier)
          .updateFoodRecord(original.copyWith(endDate: DateTime(2026, 3, 1)));

      expect(records.single.endDate, DateTime(2026, 3, 1));
      final state = await container.read(foodRecordsProvider('pet-1').future);
      expect(state.single.isOngoing, isFalse);
    });

    test('deleteFoodRecord elimina el registro y refresca el estado', () async {
      final original = FoodRecord(
        id: 1,
        petId: 'pet-1',
        foodName: 'Croquetas',
        startDate: DateTime(2026, 1, 1),
      );
      final records = <FoodRecord>[original];
      final container = buildContainer(records);

      await container.read(foodRecordsProvider('pet-1').notifier).deleteFoodRecord(1);

      expect(records, isEmpty);
      final state = await container.read(foodRecordsProvider('pet-1').future);
      expect(state, isEmpty);
    });

    test('refresh() vuelve a consultar el repository', () async {
      final records = <FoodRecord>[
        FoodRecord(id: 1, petId: 'pet-1', foodName: 'Croquetas', startDate: DateTime(2026, 1, 1)),
      ];
      final container = buildContainer(records);
      await container.read(foodRecordsProvider('pet-1').future);

      records.add(
        FoodRecord(id: 2, petId: 'pet-1', foodName: 'Pollo hervido', startDate: DateTime(2026, 2, 1)),
      );

      await container.read(foodRecordsProvider('pet-1').notifier).refresh();

      final state = await container.read(foodRecordsProvider('pet-1').future);
      expect(state, hasLength(2));
    });
  });
}
