// Pruebas de DewormingRepository: confirma que delega correctamente en
// DatabaseHelper. Deliberadamente NO usa el canal mockeado de
// flutter_local_notifications -el repository es solo acceso a datos, no
// programa ni cancela recordatorios; eso vive en DewormingsNotifier y se
// prueba aparte en test/providers/deworming_providers_test.dart-.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/deworming.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/repositories/deworming_repository.dart';

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
    // weight_record_repository_test.dart) compartan el mismo pet_pal_v2.db
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

  late DewormingRepository repository;

  setUp(() {
    repository = DewormingRepository(DatabaseHelper());
  });

  group('DewormingRepository', () {
    test('insertDeworming + getDewormingsForPet devuelven lo insertado', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      await repository.insertDeworming(Deworming(
        petId: pet.id,
        product: 'ProductoA',
        date: DateTime(2026, 1, 1),
      ));
      await repository.insertDeworming(Deworming(
        petId: pet.id,
        product: 'ProductoB',
        date: DateTime(2026, 2, 1),
        nextDate: DateTime(2026, 5, 1),
      ));

      final records = await repository.getDewormingsForPet(pet.id);
      expect(records, hasLength(2));
    });

    test('getDewormingsForPet no devuelve registros de otra mascota', () async {
      final dbHelper = DatabaseHelper();
      final petA = await _insertSamplePet(dbHelper);
      final petB = await _insertSamplePet(dbHelper);

      await repository.insertDeworming(
        Deworming(petId: petA.id, product: 'ProductoA', date: DateTime(2026, 1, 1)),
      );
      await repository.insertDeworming(
        Deworming(petId: petB.id, product: 'ProductoB', date: DateTime(2026, 1, 1)),
      );

      final recordsA = await repository.getDewormingsForPet(petA.id);
      expect(recordsA, hasLength(1));
      expect(recordsA.first.petId, petA.id);
    });

    test('updateDeworming actualiza el registro existente', () async {
      final pet = await _insertSamplePet(DatabaseHelper());
      final id = 'deworming-1';

      await repository.insertDeworming(Deworming(
        id: id,
        petId: pet.id,
        product: 'ProductoA',
        date: DateTime(2026, 1, 1),
      ));

      final inserted = (await repository.getDewormingsForPet(pet.id)).first;
      await repository.updateDeworming(
        inserted.copyWith(nextDate: DateTime(2026, 6, 1)),
      );

      final updated = (await repository.getDewormingsForPet(pet.id)).first;
      expect(updated.nextDate, DateTime(2026, 6, 1));
    });

    test('deleteDeworming elimina el registro', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      await repository.insertDeworming(
        Deworming(id: 'deworming-2', petId: pet.id, product: 'ProductoA', date: DateTime(2026, 1, 1)),
      );

      await repository.deleteDeworming('deworming-2');

      expect(await repository.getDewormingsForPet(pet.id), isEmpty);
    });
  });
}
