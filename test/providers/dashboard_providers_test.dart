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
import 'package:pet_pal/models/deworming.dart';
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

    test(
        'con múltiples aplicaciones históricas del MISMO producto, solo '
        'expone la próxima del registro con fecha de aplicación más '
        'reciente', () async {
      final dbHelper = DatabaseHelper();
      final pet = await _insertPet(dbHelper, 'Firulais');

      // Registro viejo: ya fue superado por una aplicación más nueva del
      // mismo producto, su "próxima" quedó obsoleta.
      await dbHelper.insertDeworming(Deworming(
        id: 'deworming-viejo',
        petId: pet.id,
        product: 'Drontal',
        date: DateTime.now().subtract(const Duration(days: 60)),
        nextDate: DateTime.now().subtract(const Duration(days: 30)),
      ));
      // Registro más reciente (fecha de aplicación más nueva) del mismo
      // producto: su "próxima" es la que debería sobrevivir.
      await dbHelper.insertDeworming(Deworming(
        id: 'deworming-nuevo',
        petId: pet.id,
        product: 'Drontal',
        date: DateTime.now().subtract(const Duration(days: 10)),
        nextDate: DateTime.now().add(const Duration(days: 20)),
      ));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final events = await container.read(todayDashboardProvider.future);

      final nextDewormingEvents =
          events.where((e) => e.type == 'next_deworming').toList();
      expect(nextDewormingEvents, hasLength(1));
      expect(nextDewormingEvents.first.title, 'Próxima desparasitación: Drontal');
    });

    test(
        'con vacunas de nombres DISTINTOS, el panel muestra la de próxima '
        'dosis más cercana en vez de la de la vacuna aplicada más '
        'recientemente', () async {
      final dbHelper = DatabaseHelper();
      final pet = await _insertPet(dbHelper, 'Firulais');

      // Rabia: aplicada hace tiempo, pero su próxima dosis es la más
      // cercana (ej. este mes) — es la que debería ganar en el panel.
      await dbHelper.insertVaccination(Vaccination(
        petId: pet.id,
        vaccineName: 'Rabia',
        date: DateTime.now().subtract(const Duration(days: 300)),
        nextDueDate: DateTime.now().add(const Duration(days: 10)),
      ));
      // Polivalente: aplicada más recientemente, pero su próxima dosis
      // está mucho más lejos en el tiempo — no debería tapar a Rabia.
      await dbHelper.insertVaccination(Vaccination(
        petId: pet.id,
        vaccineName: 'Polivalente',
        date: DateTime.now().subtract(const Duration(days: 5)),
        nextDueDate: DateTime.now().add(const Duration(days: 365)),
      ));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final events = await container.read(todayDashboardProvider.future);

      final nextVaccinationEvents =
          events.where((e) => e.type == 'next_vaccination').toList();
      expect(nextVaccinationEvents, hasLength(1));
      expect(nextVaccinationEvents.first.title, 'Próxima Dosis: Rabia');
    });

    test(
        'con varias citas futuras, el panel muestra solo la más próxima',
        () async {
      final dbHelper = DatabaseHelper();
      final pet = await _insertPet(dbHelper, 'Firulais');

      await dbHelper.insertAppointment(Appointment(
        petId: pet.id,
        dateTime: DateTime.now().add(const Duration(days: 30)),
        title: 'Control lejano',
      ));
      await dbHelper.insertAppointment(Appointment(
        petId: pet.id,
        dateTime: DateTime.now().add(const Duration(days: 3)),
        title: 'Control cercano',
      ));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final events = await container.read(todayDashboardProvider.future);

      final appointmentEvents =
          events.where((e) => e.type == 'appointment').toList();
      expect(appointmentEvents, hasLength(1));
      expect(appointmentEvents.first.title, 'Cita: Control cercano');
    });

    test(
        'si todas las citas de una mascota están vencidas, el panel muestra '
        'la menos vencida en vez de ocultarlas', () async {
      final dbHelper = DatabaseHelper();
      final pet = await _insertPet(dbHelper, 'Firulais');

      await dbHelper.insertAppointment(Appointment(
        petId: pet.id,
        dateTime: DateTime.now().subtract(const Duration(days: 20)),
        title: 'Vencida hace mucho',
      ));
      await dbHelper.insertAppointment(Appointment(
        petId: pet.id,
        dateTime: DateTime.now().subtract(const Duration(days: 2)),
        title: 'Vencida hace poco',
      ));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final events = await container.read(todayDashboardProvider.future);

      final appointmentEvents =
          events.where((e) => e.type == 'appointment').toList();
      expect(appointmentEvents, hasLength(1));
      expect(appointmentEvents.first.title, 'Cita: Vencida hace poco');
    });
  });
}
