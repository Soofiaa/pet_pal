// Pruebas de VaccinationRepository: confirma que delega correctamente en
// DatabaseHelper. Deliberadamente NO usa el canal mockeado de
// flutter_local_notifications ni archivos reales -el repository es solo
// acceso a datos, no programa/cancela recordatorios ni gestiona fotos; eso
// vive en VaccinationsNotifier y se prueba aparte en
// test/providers/vaccination_providers_test.dart-.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/vaccination.dart';
import 'package:pet_pal/repositories/vaccination_repository.dart';

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
    // Ruta propia de este archivo: evita compartir el mismo pet_pal_v2.db
    // físico con otros archivos que también usan sqflite_common_ffi
    // (database_helper_test.dart, weight_record_repository_test.dart,
    // deworming_repository_test.dart) cuando corren en paralelo ->
    // "database is locked".
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

  late VaccinationRepository repository;

  setUp(() {
    repository = VaccinationRepository(DatabaseHelper());
  });

  group('VaccinationRepository', () {
    test('insertVaccination + getVaccinationsForPet devuelven lo insertado', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      await repository.insertVaccination(Vaccination(
        petId: pet.id,
        vaccineName: 'Rabia',
        date: DateTime(2026, 1, 1),
      ));
      await repository.insertVaccination(Vaccination(
        petId: pet.id,
        vaccineName: 'Parvovirus',
        date: DateTime(2026, 2, 1),
        nextDueDate: DateTime(2026, 5, 1),
      ));

      final records = await repository.getVaccinationsForPet(pet.id);
      expect(records, hasLength(2));
    });

    test('getVaccinationsForPet no devuelve registros de otra mascota', () async {
      final dbHelper = DatabaseHelper();
      final petA = await _insertSamplePet(dbHelper);
      final petB = await _insertSamplePet(dbHelper);

      await repository.insertVaccination(
        Vaccination(petId: petA.id, vaccineName: 'Rabia', date: DateTime(2026, 1, 1)),
      );
      await repository.insertVaccination(
        Vaccination(petId: petB.id, vaccineName: 'Parvovirus', date: DateTime(2026, 1, 1)),
      );

      final recordsA = await repository.getVaccinationsForPet(petA.id);
      expect(recordsA, hasLength(1));
      expect(recordsA.first.petId, petA.id);
    });

    test('updateVaccination actualiza el registro existente', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      final vaccination = Vaccination(
        petId: pet.id,
        vaccineName: 'Rabia',
        date: DateTime(2026, 1, 1),
      );
      await repository.insertVaccination(vaccination);

      await repository.updateVaccination(
        vaccination.copyWith(nextDueDate: DateTime(2026, 6, 1)),
      );

      final updated = (await repository.getVaccinationsForPet(pet.id)).first;
      expect(updated.nextDueDate, DateTime(2026, 6, 1));
    });

    test('deleteVaccination elimina el registro', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      final vaccination = Vaccination(
        petId: pet.id,
        vaccineName: 'Rabia',
        date: DateTime(2026, 1, 1),
      );
      await repository.insertVaccination(vaccination);

      await repository.deleteVaccination(vaccination.id);

      expect(await repository.getVaccinationsForPet(pet.id), isEmpty);
    });
  });
}
