// Pruebas de WeightRecordRepository: confirma que delega correctamente en
// DatabaseHelper (hoy es casi un pass-through, pero es la capa que las
// pantallas usan de ahora en más). Usa la misma base sqflite_common_ffi
// que test/data/database_helper_test.dart, ya que acá sí queremos SQLite
// real de punta a punta, no un fake — lo que se está probando es la
// delegación real hacia la base de datos.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/weight_record.dart';
import 'package:pet_pal/repositories/weight_record_repository.dart';

Future<Pet> _insertSamplePet(DatabaseHelper dbHelper) async {
  final pet = Pet(
    name: 'Firulais',
    species: 'Perro',
    breed: 'Mestizo',
    dob: DateTime(2020, 1, 1),
    color: 'Marrón',
  );
  await dbHelper.insertPet(pet);
  return pet;
}

void main() {
  late Directory tempDbDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Ruta propia de este archivo: evita que este y otros archivos que
    // también usan sqflite_common_ffi (database_helper_test.dart,
    // deworming_repository_test.dart) compartan el mismo pet_pal_v2.db
    // físico cuando corren en paralelo -> "database is locked".
    tempDbDir = await Directory.systemTemp.createTemp('pet_pal_test_db_');
    // ignore: deprecated_member_use
    await databaseFactory.setDatabasesPath(tempDbDir.path);
  });

  tearDownAll(() async {
    // Mejor esfuerzo, no crítico: DatabaseHelper es un singleton que nunca
    // cierra su conexión, así que en Windows el archivo .db puede seguir
    // con un handle abierto acá y el borrado fallar (PathAccessException).
    // No debe hacer fallar la corrida por una limpieza que es solo prolijidad.
    try {
      if (await tempDbDir.exists()) {
        await tempDbDir.delete(recursive: true);
      }
    } catch (_) {
      // Se ignora: el SO limpia temporales eventualmente.
    }
  });

  setUp(() async {
    await DatabaseHelper().deleteAllData();
  });

  late WeightRecordRepository repository;

  setUp(() {
    repository = WeightRecordRepository(DatabaseHelper());
  });

  group('WeightRecordRepository', () {
    test('insertWeightRecord + getWeightRecordsForPet devuelven lo insertado', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      await repository.insertWeightRecord(
        WeightRecord(petId: pet.id, weight: 10.5, date: DateTime(2026, 1, 1)),
      );
      await repository.insertWeightRecord(
        WeightRecord(petId: pet.id, weight: 11.2, date: DateTime(2026, 2, 1)),
      );

      final records = await repository.getWeightRecordsForPet(pet.id);
      expect(records, hasLength(2));
    });

    test('getWeightRecordsForPet no devuelve registros de otra mascota', () async {
      final dbHelper = DatabaseHelper();
      final petA = await _insertSamplePet(dbHelper);
      final petB = await _insertSamplePet(dbHelper);

      await repository.insertWeightRecord(
        WeightRecord(petId: petA.id, weight: 10.0, date: DateTime(2026, 1, 1)),
      );
      await repository.insertWeightRecord(
        WeightRecord(petId: petB.id, weight: 5.0, date: DateTime(2026, 1, 1)),
      );

      final recordsA = await repository.getWeightRecordsForPet(petA.id);
      expect(recordsA, hasLength(1));
      expect(recordsA.first.petId, petA.id);
    });

    test('updateWeightRecord actualiza el valor existente', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      await repository.insertWeightRecord(
        WeightRecord(petId: pet.id, weight: 10.0, date: DateTime(2026, 1, 1)),
      );

      final inserted = (await repository.getWeightRecordsForPet(pet.id)).first;
      await repository.updateWeightRecord(inserted.copyWith(weight: 12.3));

      final updated = (await repository.getWeightRecordsForPet(pet.id)).first;
      expect(updated.weight, 12.3);
    });

    test('deleteWeightRecord elimina el registro', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      await repository.insertWeightRecord(
        WeightRecord(petId: pet.id, weight: 10.0, date: DateTime(2026, 1, 1)),
      );

      final inserted = (await repository.getWeightRecordsForPet(pet.id)).first;
      await repository.deleteWeightRecord(inserted.id!);

      expect(await repository.getWeightRecordsForPet(pet.id), isEmpty);
    });
  });
}
