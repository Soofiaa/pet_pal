// Pruebas de FoodRecordRepository: confirma que delega correctamente en
// DatabaseHelper contra sqlite real (no un fake), igual que
// food_allergy_repository_test.dart -sin archivos ni ReminderScheduler que
// mockear-.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/food_record.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/repositories/food_record_repository.dart';

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
    // también usan sqflite_common_ffi compartan el mismo pet_pal_v2.db
    // físico cuando corren en paralelo -> "database is locked".
    tempDbDir = await Directory.systemTemp.createTemp('pet_pal_test_db_');
    // ignore: deprecated_member_use
    await databaseFactory.setDatabasesPath(tempDbDir.path);
  });

  tearDownAll(() async {
    // Mejor esfuerzo, no crítico: DatabaseHelper es un singleton que nunca
    // cierra su conexión, así que en Windows el archivo .db puede seguir
    // con un handle abierto acá y el borrado fallar (PathAccessException).
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

  late FoodRecordRepository repository;

  setUp(() {
    repository = FoodRecordRepository(DatabaseHelper());
  });

  group('FoodRecordRepository', () {
    test('insertFoodRecord + getFoodRecordsForPet devuelven lo insertado', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      await repository.insertFoodRecord(FoodRecord(
        petId: pet.id,
        foodName: 'Croquetas',
        startDate: DateTime(2026, 1, 1),
      ));
      await repository.insertFoodRecord(FoodRecord(
        petId: pet.id,
        foodName: 'Pollo hervido',
        startDate: DateTime(2026, 2, 1),
      ));

      final records = await repository.getFoodRecordsForPet(pet.id);
      expect(records, hasLength(2));
    });

    test('getFoodRecordsForPet no devuelve registros de otra mascota', () async {
      final dbHelper = DatabaseHelper();
      final petA = await _insertSamplePet(dbHelper);
      final petB = await _insertSamplePet(dbHelper);

      await repository.insertFoodRecord(FoodRecord(
        petId: petA.id,
        foodName: 'Croquetas',
        startDate: DateTime(2026, 1, 1),
      ));
      await repository.insertFoodRecord(FoodRecord(
        petId: petB.id,
        foodName: 'Pollo hervido',
        startDate: DateTime(2026, 1, 1),
      ));

      final recordsA = await repository.getFoodRecordsForPet(petA.id);
      expect(recordsA, hasLength(1));
      expect(recordsA.first.petId, petA.id);
    });

    test('insertFoodRecord con startDate null persiste y relee como null', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      await repository.insertFoodRecord(FoodRecord(
        petId: pet.id,
        foodName: 'Croquetas',
        startDate: null,
        notes: 'No recuerda cuándo empezó',
      ));

      final records = await repository.getFoodRecordsForPet(pet.id);
      expect(records, hasLength(1));
      expect(records.single.startDate, isNull);
      expect(records.single.notes, 'No recuerda cuándo empezó');
    });

    test('insertFoodRecord con endDate null persiste como "lo sigue comiendo"', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      await repository.insertFoodRecord(FoodRecord(
        petId: pet.id,
        foodName: 'Croquetas',
        startDate: DateTime(2026, 1, 1),
        endDate: null,
      ));

      final records = await repository.getFoodRecordsForPet(pet.id);
      expect(records.single.endDate, isNull);
      expect(records.single.isOngoing, isTrue);
    });

    test(
      'insertFoodRecord con isOngoing: false y endDate null persiste y relee '
      '"dejó de comerlo, fecha desconocida" sin confundirlo con "sigue comiendo"',
      () async {
        final pet = await _insertSamplePet(DatabaseHelper());

        await repository.insertFoodRecord(FoodRecord(
          petId: pet.id,
          foodName: 'Croquetas',
          startDate: DateTime(2026, 1, 1),
          endDate: null,
          isOngoing: false,
        ));

        final records = await repository.getFoodRecordsForPet(pet.id);
        expect(records.single.endDate, isNull);
        expect(records.single.isOngoing, isFalse);
      },
    );

    test('updateFoodRecord permite pasar de "lo sigue comiendo" a tener endDate', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      await repository.insertFoodRecord(FoodRecord(
        petId: pet.id,
        foodName: 'Croquetas',
        startDate: DateTime(2026, 1, 1),
      ));

      final inserted = (await repository.getFoodRecordsForPet(pet.id)).first;
      expect(inserted.isOngoing, isTrue);

      await repository.updateFoodRecord(inserted.copyWith(endDate: DateTime(2026, 3, 1)));

      final updated = (await repository.getFoodRecordsForPet(pet.id)).first;
      expect(updated.isOngoing, isFalse);
      expect(updated.endDate, DateTime(2026, 3, 1));
    });

    test('deleteFoodRecord elimina el registro', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      await repository.insertFoodRecord(FoodRecord(
        petId: pet.id,
        foodName: 'Croquetas',
        startDate: DateTime(2026, 1, 1),
      ));

      final inserted = (await repository.getFoodRecordsForPet(pet.id)).first;
      await repository.deleteFoodRecord(inserted.id!);

      expect(await repository.getFoodRecordsForPet(pet.id), isEmpty);
    });
  });
}
