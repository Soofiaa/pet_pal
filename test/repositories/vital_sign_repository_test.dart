// Pruebas de VitalSignRepository: mismo esqueleto que
// weight_record_repository_test.dart, con sqflite_common_ffi real.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/vital_sign_config.dart';
import 'package:pet_pal/models/vital_sign_record.dart';
import 'package:pet_pal/repositories/vital_sign_repository.dart';

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
    tempDbDir = await Directory.systemTemp.createTemp('pet_pal_test_db_');
    // ignore: deprecated_member_use
    await databaseFactory.setDatabasesPath(tempDbDir.path);
  });

  tearDownAll(() async {
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

  late VitalSignRepository repository;

  setUp(() {
    repository = VitalSignRepository(DatabaseHelper());
  });

  group('VitalSignRepository', () {
    test('insertVitalSignRecord + getVitalSignRecordsForPet devuelven lo insertado', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      await repository.insertVitalSignRecord(
        VitalSignRecord(petId: pet.id, type: VitalSignType.temperature, value: 38.5, date: DateTime(2026, 1, 1)),
      );
      await repository.insertVitalSignRecord(
        VitalSignRecord(petId: pet.id, type: VitalSignType.temperature, value: 39.0, date: DateTime(2026, 2, 1)),
      );

      final records = await repository.getVitalSignRecordsForPet(pet.id);
      expect(records, hasLength(2));
    });

    test('getVitalSignRecordsForPet no devuelve registros de otra mascota', () async {
      final dbHelper = DatabaseHelper();
      final petA = await _insertSamplePet(dbHelper);
      final petB = await _insertSamplePet(dbHelper);

      await repository.insertVitalSignRecord(
        VitalSignRecord(petId: petA.id, type: VitalSignType.temperature, value: 38.5, date: DateTime(2026, 1, 1)),
      );
      await repository.insertVitalSignRecord(
        VitalSignRecord(petId: petB.id, type: VitalSignType.temperature, value: 39.5, date: DateTime(2026, 1, 1)),
      );

      final recordsA = await repository.getVitalSignRecordsForPet(petA.id);
      expect(recordsA, hasLength(1));
      expect(recordsA.first.petId, petA.id);
    });

    test('getVitalSignRecordsForPet filtra por tipo cuando se pide', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      await repository.insertVitalSignRecord(
        VitalSignRecord(petId: pet.id, type: VitalSignType.temperature, value: 38.5, date: DateTime(2026, 1, 1)),
      );

      final filtered = await repository.getVitalSignRecordsForPet(
        pet.id,
        type: VitalSignType.temperature,
      );
      expect(filtered, hasLength(1));
    });

    test('updateVitalSignRecord actualiza el valor existente', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      await repository.insertVitalSignRecord(
        VitalSignRecord(petId: pet.id, type: VitalSignType.temperature, value: 38.5, date: DateTime(2026, 1, 1)),
      );

      final inserted = (await repository.getVitalSignRecordsForPet(pet.id)).first;
      await repository.updateVitalSignRecord(inserted.copyWith(value: 40.1));

      final updated = (await repository.getVitalSignRecordsForPet(pet.id)).first;
      expect(updated.value, 40.1);
    });

    test('deleteVitalSignRecord elimina el registro', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      await repository.insertVitalSignRecord(
        VitalSignRecord(petId: pet.id, type: VitalSignType.temperature, value: 38.5, date: DateTime(2026, 1, 1)),
      );

      final inserted = (await repository.getVitalSignRecordsForPet(pet.id)).first;
      await repository.deleteVitalSignRecord(inserted.id!);

      expect(await repository.getVitalSignRecordsForPet(pet.id), isEmpty);
    });
  });
}
