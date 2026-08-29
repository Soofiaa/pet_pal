// Pruebas de FoodAllergyRepository: confirma que delega correctamente en
// DatabaseHelper contra sqlite real (no un fake), igual que
// weight_record_repository_test.dart -es el caso más simple de las cuatro
// migraciones, sin archivos ni ReminderScheduler que mockear-.
//
// Incluye una prueba dedicada al crash histórico de esta entidad
// (commit cdf4787): FoodAllergy.toJson()/fromJson() mapeaban un campo
// 'food' que no existía como columna en la tabla food_allergies -la
// columna real, del esquema original, se llama 'allergies'-, así que
// insertFoodAllergy lanzaba una excepción en cada intento de guardar y
// ninguna fila se había guardado nunca. Este repository no reconstruye el
// mapa a mano en ningún punto, así que no puede reintroducir ese
// desajuste, pero la prueba deja el comportamiento correcto anclado igual
// -acá, contra sqlite real, y no solo en el modelo-.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/food_allergy.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/repositories/food_allergy_repository.dart';

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

  late FoodAllergyRepository repository;

  setUp(() {
    repository = FoodAllergyRepository(DatabaseHelper());
  });

  group('FoodAllergyRepository', () {
    test(
      'insertFoodAllergy no lanza excepción y persiste el campo food '
      '(regresión del crash histórico: columna real es "allergies", no "food")',
      () async {
        final pet = await _insertSamplePet(DatabaseHelper());

        // No debe lanzar: antes de la corrección de cdf4787 esto fallaba
        // siempre, en cualquier intento de guardar una alergia.
        await repository.insertFoodAllergy(FoodAllergy(
          petId: pet.id,
          food: 'Pollo',
          dateRecorded: DateTime(2026, 1, 1),
        ));

        final records = await repository.getFoodAllergiesForPet(pet.id);
        expect(records, hasLength(1));
        expect(records.single.food, 'Pollo');
      },
    );

    test('insertFoodAllergy + getFoodAllergiesForPet devuelven lo insertado', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      await repository.insertFoodAllergy(FoodAllergy(
        petId: pet.id,
        food: 'Pollo',
        dateRecorded: DateTime(2026, 1, 1),
      ));
      await repository.insertFoodAllergy(FoodAllergy(
        petId: pet.id,
        food: 'Trigo',
        dateRecorded: DateTime(2026, 2, 1),
      ));

      final records = await repository.getFoodAllergiesForPet(pet.id);
      expect(records, hasLength(2));
    });

    test('getFoodAllergiesForPet no devuelve registros de otra mascota', () async {
      final dbHelper = DatabaseHelper();
      final petA = await _insertSamplePet(dbHelper);
      final petB = await _insertSamplePet(dbHelper);

      await repository.insertFoodAllergy(FoodAllergy(
        petId: petA.id,
        food: 'Pollo',
        dateRecorded: DateTime(2026, 1, 1),
      ));
      await repository.insertFoodAllergy(FoodAllergy(
        petId: petB.id,
        food: 'Res',
        dateRecorded: DateTime(2026, 1, 1),
      ));

      final recordsA = await repository.getFoodAllergiesForPet(petA.id);
      expect(recordsA, hasLength(1));
      expect(recordsA.first.petId, petA.id);
    });

    test('updateFoodAllergy actualiza el valor existente', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      await repository.insertFoodAllergy(FoodAllergy(
        petId: pet.id,
        food: 'Pollo',
        dateRecorded: DateTime(2026, 1, 1),
      ));

      final inserted = (await repository.getFoodAllergiesForPet(pet.id)).first;
      await repository.updateFoodAllergy(inserted.copyWith(food: 'Pollo y derivados'));

      final updated = (await repository.getFoodAllergiesForPet(pet.id)).first;
      expect(updated.food, 'Pollo y derivados');
    });

    test('deleteFoodAllergy elimina el registro', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      await repository.insertFoodAllergy(FoodAllergy(
        petId: pet.id,
        food: 'Pollo',
        dateRecorded: DateTime(2026, 1, 1),
      ));

      final inserted = (await repository.getFoodAllergiesForPet(pet.id)).first;
      await repository.deleteFoodAllergy(inserted.id!);

      expect(await repository.getFoodAllergiesForPet(pet.id), isEmpty);
    });
  });
}
