// Pruebas de todayDashboardProvider: usa sqflite_common_ffi real (mismo
// patrón que weight_record_repository_test.dart) porque lo que se prueba
// acá es la agregación real a través de DatabaseHelper.getAllEventsForPet
// para múltiples mascotas, no solo la forma del provider.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/appointment.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/vaccination.dart';
import 'package:pet_pal/providers/dashboard_providers.dart';

Future<Pet> _insertPet(DatabaseHelper dbHelper, String name) async {
  final pet = Pet(
    name: name,
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

  group('todayDashboardProvider', () {
    test('agrega eventos accionables de múltiples mascotas', () async {
      final dbHelper = DatabaseHelper();
      final petA = await _insertPet(dbHelper, 'Firulais');
      final petB = await _insertPet(dbHelper, 'Michi');

      await dbHelper.insertAppointment(Appointment(
        petId: petA.id,
        dateTime: DateTime.now().add(const Duration(days: 2)),
        title: 'Control anual',
      ));
      await dbHelper.insertVaccination(Vaccination(
        petId: petB.id,
        vaccineName: 'Rabia',
        date: DateTime.now().subtract(const Duration(days: 300)),
        nextDueDate: DateTime.now().add(const Duration(days: 3)),
      ));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final events = await container.read(todayDashboardProvider.future);

      expect(events.map((e) => e.petName).toSet(), {'Firulais', 'Michi'});
      expect(events.any((e) => e.type == 'appointment'), isTrue);
      expect(events.any((e) => e.type == 'next_vaccination'), isTrue);
    });

    test('ordena por urgencia: un evento vencido va antes que uno futuro', () async {
      final dbHelper = DatabaseHelper();
      final petA = await _insertPet(dbHelper, 'Firulais');
      final petB = await _insertPet(dbHelper, 'Michi');

      await dbHelper.insertAppointment(Appointment(
        petId: petA.id,
        dateTime: DateTime.now().add(const Duration(days: 10)),
        title: 'Control futuro',
      ));
      await dbHelper.insertAppointment(Appointment(
        petId: petB.id,
        dateTime: DateTime.now().subtract(const Duration(days: 2)),
        title: 'Control vencido',
      ));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final events = await container.read(todayDashboardProvider.future);

      expect(events.first.title, 'Cita: Control vencido');
    });

    test('excluye eventos no accionables y citas ya completadas', () async {
      final dbHelper = DatabaseHelper();
      final pet = await _insertPet(dbHelper, 'Firulais');

      // Registro histórico (sin próxima dosis): no es accionable.
      await dbHelper.insertVaccination(Vaccination(
        petId: pet.id,
        vaccineName: 'Rabia',
        date: DateTime.now().subtract(const Duration(days: 5)),
      ));
      // Cita ya completada: no debe aparecer en el dashboard.
      await dbHelper.insertAppointment(Appointment(
        petId: pet.id,
        dateTime: DateTime.now().add(const Duration(days: 1)),
        title: 'Cita completada',
        isCompleted: true,
      ));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final events = await container.read(todayDashboardProvider.future);

      expect(events, isEmpty);
    });

    test('una mascota sin eventos no rompe la agregación', () async {
      final dbHelper = DatabaseHelper();
      final petWithEvents = await _insertPet(dbHelper, 'Firulais');
      await _insertPet(dbHelper, 'Michi sin eventos');

      await dbHelper.insertAppointment(Appointment(
        petId: petWithEvents.id,
        dateTime: DateTime.now().add(const Duration(days: 1)),
        title: 'Control',
      ));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final events = await container.read(todayDashboardProvider.future);

      expect(events, hasLength(1));
      expect(events.first.petName, 'Firulais');
    });
  });
}
