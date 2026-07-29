// Pruebas de MedicationRepository: confirma que delega correctamente en
// DatabaseHelper. Deliberadamente NO usa el canal mockeado de
// flutter_local_notifications -el repository es solo acceso a datos, no
// programa ni cancela recordatorios; eso vive en MedicationsNotifier y se
// prueba aparte en test/providers/medication_providers_test.dart-.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/medication.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/repositories/medication_repository.dart';

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
    // weight_record_repository_test.dart, deworming_repository_test.dart,
    // vaccination_repository_test.dart) compartan el mismo pet_pal_v2.db
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

  late MedicationRepository repository;

  setUp(() {
    repository = MedicationRepository(DatabaseHelper());
  });

  group('MedicationRepository', () {
    test('insertMedication + getMedicationsForPet devuelven lo insertado', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      await repository.insertMedication(Medication(
        petId: pet.id,
        name: 'Antibiótico',
        dosage: '1 comprimido',
        frequency: 'Cada 8 horas',
        notes: '',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 10),
        reminderTimes: const ['08:00', '16:00'],
      ));
      await repository.insertMedication(Medication(
        petId: pet.id,
        name: 'Antiinflamatorio',
        dosage: '5 ml',
        frequency: '',
        notes: '',
        startDate: DateTime(2026, 2, 1),
      ));

      final records = await repository.getMedicationsForPet(pet.id);
      expect(records, hasLength(2));
    });

    test('getMedicationsForPet no devuelve registros de otra mascota', () async {
      final dbHelper = DatabaseHelper();
      final petA = await _insertSamplePet(dbHelper);
      final petB = await _insertSamplePet(dbHelper);

      await repository.insertMedication(Medication(
        petId: petA.id,
        name: 'Antibiótico',
        dosage: '1',
        frequency: '',
        notes: '',
        startDate: DateTime(2026, 1, 1),
      ));
      await repository.insertMedication(Medication(
        petId: petB.id,
        name: 'Antiinflamatorio',
        dosage: '1',
        frequency: '',
        notes: '',
        startDate: DateTime(2026, 1, 1),
      ));

      final recordsA = await repository.getMedicationsForPet(petA.id);
      expect(recordsA, hasLength(1));
      expect(recordsA.first.petId, petA.id);
    });

    test('updateMedication actualiza el registro existente', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      final medication = Medication(
        id: 'medication-1',
        petId: pet.id,
        name: 'Antibiótico',
        dosage: '1 comprimido',
        frequency: '',
        notes: '',
        startDate: DateTime(2026, 1, 1),
      );
      await repository.insertMedication(medication);

      await repository.updateMedication(
        medication.copyWith(endDate: DateTime(2026, 6, 1)),
      );

      final updated = (await repository.getMedicationsForPet(pet.id)).first;
      expect(updated.endDate, DateTime(2026, 6, 1));
    });

    test('deleteMedication elimina el registro', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      await repository.insertMedication(Medication(
        id: 'medication-2',
        petId: pet.id,
        name: 'Antibiótico',
        dosage: '1',
        frequency: '',
        notes: '',
        startDate: DateTime(2026, 1, 1),
      ));

      await repository.deleteMedication('medication-2');

      expect(await repository.getMedicationsForPet(pet.id), isEmpty);
    });
  });
}
