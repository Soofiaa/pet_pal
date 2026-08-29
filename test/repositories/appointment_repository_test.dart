// Pruebas de AppointmentRepository: confirma que delega correctamente en
// DatabaseHelper. Deliberadamente NO usa el canal mockeado de
// flutter_local_notifications -el repository es solo acceso a datos, no
// orquesta el recordatorio; eso vive en AppointmentsNotifier y se prueba
// aparte en test/providers/appointment_providers_test.dart-.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/appointment.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/repositories/appointment_repository.dart';

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

  late AppointmentRepository repository;

  setUp(() {
    repository = AppointmentRepository(DatabaseHelper());
  });

  group('AppointmentRepository', () {
    test('insertAppointment + getAppointmentsForPet devuelven lo insertado', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      await repository.insertAppointment(Appointment(
        petId: pet.id,
        dateTime: DateTime(2026, 1, 1, 10, 0),
        title: 'Control anual',
      ));
      await repository.insertAppointment(Appointment(
        petId: pet.id,
        dateTime: DateTime(2026, 2, 1, 15, 30),
        title: 'Vacunación',
        location: 'Clínica X',
      ));

      final records = await repository.getAppointmentsForPet(pet.id);
      expect(records, hasLength(2));
    });

    test('getAppointmentsForPet no devuelve registros de otra mascota', () async {
      final dbHelper = DatabaseHelper();
      final petA = await _insertSamplePet(dbHelper);
      final petB = await _insertSamplePet(dbHelper);

      await repository.insertAppointment(Appointment(
        petId: petA.id,
        dateTime: DateTime(2026, 1, 1),
        title: 'Cita A',
      ));
      await repository.insertAppointment(Appointment(
        petId: petB.id,
        dateTime: DateTime(2026, 1, 1),
        title: 'Cita B',
      ));

      final recordsA = await repository.getAppointmentsForPet(petA.id);
      expect(recordsA, hasLength(1));
      expect(recordsA.first.petId, petA.id);
    });

    test('updateAppointment actualiza el registro existente', () async {
      final pet = await _insertSamplePet(DatabaseHelper());
      const id = 'appointment-1';

      await repository.insertAppointment(Appointment(
        id: id,
        petId: pet.id,
        dateTime: DateTime(2026, 1, 1),
        title: 'Control anual',
      ));

      final inserted = (await repository.getAppointmentsForPet(pet.id)).first;
      await repository.updateAppointment(
        inserted.copyWith(title: 'Control anual (reprogramado)', isCompleted: true),
      );

      final updated = (await repository.getAppointmentsForPet(pet.id)).first;
      expect(updated.title, 'Control anual (reprogramado)');
      expect(updated.isCompleted, isTrue);
    });

    test('deleteAppointment elimina el registro', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      await repository.insertAppointment(Appointment(
        id: 'appointment-2',
        petId: pet.id,
        dateTime: DateTime(2026, 1, 1),
        title: 'Cita',
      ));

      await repository.deleteAppointment('appointment-2');

      expect(await repository.getAppointmentsForPet(pet.id), isEmpty);
    });
  });
}
