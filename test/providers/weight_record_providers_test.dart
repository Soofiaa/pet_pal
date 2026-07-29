// Pruebas de WeightRecordsNotifier (weightRecordsProvider): esta es la
// capacidad de testing que no existía antes de este refactor. Antes, la
// lógica de carga/orden/refresh vivía adentro de un StatefulWidget con
// setState y solo era observable pumpeando un widget. Un AsyncNotifier es
// una clase Dart normal: se prueba con ProviderContainer, sin widgets,
// igual que el resto de la suite de Fase 1.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pet_pal/models/weight_record.dart';
import 'package:pet_pal/providers/weight_record_providers.dart';
import 'package:pet_pal/repositories/weight_record_repository.dart';

/// Fake en memoria: no toca sqflite en absoluto. Lo que se prueba acá es
/// el comportamiento del notifier (orden, refresh), no la base de datos
/// real -eso ya lo cubre weight_record_repository_test.dart-.
class _FakeWeightRecordRepository implements WeightRecordRepository {
  _FakeWeightRecordRepository(this.records);

  final List<WeightRecord> records;

  @override
  Future<List<WeightRecord>> getWeightRecordsForPet(String petId) async {
    return records.where((r) => r.petId == petId).toList();
  }

  @override
  Future<int> insertWeightRecord(WeightRecord record) async {
    records.add(record);
    return records.length;
  }

  @override
  Future<void> updateWeightRecord(WeightRecord record) async {
    final index = records.indexWhere((r) => r.id == record.id);
    if (index != -1) records[index] = record;
  }

  @override
  Future<void> deleteWeightRecord(int id) async {
    records.removeWhere((r) => r.id == id);
  }
}

void main() {
  group('weightRecordsProvider (WeightRecordsNotifier)', () {
    test('carga y ordena los registros por fecha ascendente', () async {
      final fakeRecords = [
        WeightRecord(id: 1, petId: 'pet-1', weight: 12.0, date: DateTime(2026, 3, 1)),
        WeightRecord(id: 2, petId: 'pet-1', weight: 11.0, date: DateTime(2026, 1, 1)),
        // De otra mascota: no debería aparecer en el resultado de 'pet-1'.
        WeightRecord(id: 3, petId: 'pet-2', weight: 5.0, date: DateTime(2026, 2, 1)),
      ];

      final container = ProviderContainer(
        overrides: [
          weightRecordRepositoryProvider.overrideWithValue(
            _FakeWeightRecordRepository(fakeRecords),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(weightRecordsProvider('pet-1').future);

      expect(result.map((r) => r.id).toList(), [2, 1]);
    });

    test('el estado pasa por loading y termina en data', () async {
      final fakeRecords = [
        WeightRecord(id: 1, petId: 'pet-1', weight: 10.0, date: DateTime(2026, 1, 1)),
      ];

      final container = ProviderContainer(
        overrides: [
          weightRecordRepositoryProvider.overrideWithValue(
            _FakeWeightRecordRepository(fakeRecords),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(weightRecordsProvider('pet-1')),
        const AsyncValue<List<WeightRecord>>.loading(),
      );

      await container.read(weightRecordsProvider('pet-1').future);

      expect(
        container.read(weightRecordsProvider('pet-1')).value,
        hasLength(1),
      );
    });

    test('refresh() vuelve a cargar después de un insert externo', () async {
      final fakeRecords = <WeightRecord>[
        WeightRecord(id: 1, petId: 'pet-1', weight: 12.0, date: DateTime(2026, 1, 1)),
      ];

      final container = ProviderContainer(
        overrides: [
          weightRecordRepositoryProvider.overrideWithValue(
            _FakeWeightRecordRepository(fakeRecords),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(weightRecordsProvider('pet-1').future);

      // Simula que se agregó un registro nuevo por fuera (ej. desde
      // add_edit_weight_record_screen.dart), y que la pantalla llama a
      // refresh() para reflejarlo.
      fakeRecords.add(
        WeightRecord(id: 2, petId: 'pet-1', weight: 13.0, date: DateTime(2026, 2, 1)),
      );

      await container.read(weightRecordsProvider('pet-1').notifier).refresh();

      expect(
        container.read(weightRecordsProvider('pet-1')).value,
        hasLength(2),
      );
    });

    test('cada mascota tiene su propio estado (family), sin mezclarse', () async {
      final fakeRecords = [
        WeightRecord(id: 1, petId: 'pet-1', weight: 10.0, date: DateTime(2026, 1, 1)),
        WeightRecord(id: 2, petId: 'pet-2', weight: 20.0, date: DateTime(2026, 1, 1)),
      ];

      final container = ProviderContainer(
        overrides: [
          weightRecordRepositoryProvider.overrideWithValue(
            _FakeWeightRecordRepository(fakeRecords),
          ),
        ],
      );
      addTearDown(container.dispose);

      final resultA = await container.read(weightRecordsProvider('pet-1').future);
      final resultB = await container.read(weightRecordsProvider('pet-2').future);

      expect(resultA.single.id, 1);
      expect(resultB.single.id, 2);
    });
  });
}
