// Pruebas de PetRepository.deletePet: a diferencia del resto de los
// repositories de esta suite, deletePet SÍ tiene un efecto secundario
// (cancela recordatorios vía ReminderScheduler antes de borrar), así que
// esta prueba combina las dos técnicas que hasta ahora vivían en archivos
// separados: DB temporal real (como deworming_repository_test.dart) y el
// canal mockeado de flutter_local_notifications (como
// deworming_providers_test.dart / reminder_scheduler_test.dart). Cubre
// justo el escenario que se nos escapó en Fase 1: home_screen.dart borraba
// la mascota llamando a DatabaseHelper().deletePet directo, sin pasar por
// este método, así que ningún recordatorio pendiente se cancelaba.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/deworming.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/repositories/pet_repository.dart';
import 'package:pet_pal/services/notification_service.dart';
import 'package:pet_pal/services/reminder_scheduler.dart';
import 'package:uuid/uuid.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel =
      MethodChannel('dexterous.com/flutter/local_notifications');

  late List<MethodCall> calls;
  late Directory tempDbDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Ruta propia de este archivo, mismo motivo que en
    // deworming_repository_test.dart: evita compartir pet_pal_v2.db físico
    // con otros archivos que corren en paralelo.
    tempDbDir = await Directory.systemTemp.createTemp('pet_pal_test_db_');
    // ignore: deprecated_member_use
    await databaseFactory.setDatabasesPath(tempDbDir.path);
    AndroidFlutterLocalNotificationsPlugin.registerWith();
  });

  tearDownAll(() async {
    try {
      if (await tempDbDir.exists()) {
        await tempDbDir.delete(recursive: true);
      }
    } catch (_) {
      // Mejor esfuerzo: ver el mismo comentario en deworming_repository_test.dart.
    }
  });

  setUp(() async {
    await DatabaseHelper().deleteAllData();
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      switch (call.method) {
        case 'initialize':
        case 'requestNotificationsPermission':
        case 'requestExactAlarmsPermission':
        case 'canScheduleExactNotifications':
        case 'areNotificationsEnabled':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  late PetRepository repository;

  setUp(() {
    repository = PetRepository(DatabaseHelper());
  });

  group('PetRepository.deletePet', () {
    test('cancela el recordatorio pendiente de la mascota antes de borrarla',
        () async {
      await NotificationService().init();
      final dbHelper = DatabaseHelper();
      final pet = await _insertSamplePet(dbHelper);

      final deworming = Deworming(
        id: const Uuid().v4(),
        petId: pet.id,
        product: 'ProductoA',
        date: DateTime.now(),
        nextDate: DateTime.now().add(const Duration(days: 30)),
      );
      await dbHelper.insertDeworming(deworming);

      // Reproduce el estado real de la app: el recordatorio ya está
      // agendado en el plugin antes de que el usuario borre la mascota.
      await ReminderScheduler.scheduleDewormingReminder(deworming);
      final scheduledId = calls
          .singleWhere((c) => c.method == 'zonedSchedule')
          .arguments['id'] as int;
      calls.clear();

      await repository.deletePet(pet.id);

      final cancelCalls = calls.where((c) => c.method == 'cancel').toList();
      expect(
        cancelCalls.map((c) => c.arguments['id'] as int),
        contains(scheduledId),
        reason:
            'deletePet debe cancelar el recordatorio de desparasitación '
            'que ya estaba agendado para esta mascota',
      );
    });

    test('borra el registro de la mascota', () async {
      final dbHelper = DatabaseHelper();
      final pet = await _insertSamplePet(dbHelper);

      await repository.deletePet(pet.id);

      expect(await dbHelper.getPetById(pet.id), isNull);
    });

    test('no falla si la mascota no tiene ningún registro con recordatorio',
        () async {
      final dbHelper = DatabaseHelper();
      final pet = await _insertSamplePet(dbHelper);

      await repository.deletePet(pet.id);

      expect(await dbHelper.getPetById(pet.id), isNull);
    });
  });
}
