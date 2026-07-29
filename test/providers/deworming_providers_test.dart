// Pruebas de DewormingsNotifier: la orquestación datos + recordatorio es
// código NUEVO (antes vivía inline en add_edit_deworming_screen.dart /
// deworming_screen.dart), así que reminder_scheduler_test.dart no la
// cubre -esa suite prueba que ReminderScheduler en sí mismo no colisiona,
// no que el notifier lo llame con los argumentos y el orden correctos-.
// Combina las dos técnicas ya usadas en la suite: un repository fake en
// memoria (como weight_record_providers_test.dart) y el canal mockeado
// de flutter_local_notifications (como reminder_scheduler_test.dart),
// porque acá sí nos interesa observar las llamadas reales a
// ReminderScheduler.
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pet_pal/models/deworming.dart';
import 'package:pet_pal/providers/deworming_providers.dart';
import 'package:pet_pal/repositories/deworming_repository.dart';
import 'package:pet_pal/services/notification_service.dart';
import 'package:uuid/uuid.dart';

class _FakeDewormingRepository implements DewormingRepository {
  _FakeDewormingRepository(this.records);

  final List<Deworming> records;

  @override
  Future<List<Deworming>> getDewormingsForPet(String petId) async {
    return records.where((r) => r.petId == petId).toList();
  }

  @override
  Future<void> insertDeworming(Deworming deworming) async {
    records.add(deworming);
  }

  @override
  Future<void> updateDeworming(Deworming deworming) async {
    final index = records.indexWhere((r) => r.id == deworming.id);
    if (index != -1) records[index] = deworming;
  }

  @override
  Future<void> deleteDeworming(String id) async {
    records.removeWhere((r) => r.id == id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel =
      MethodChannel('dexterous.com/flutter/local_notifications');

  setUpAll(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
  });

  late List<MethodCall> calls;

  setUp(() {
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

  ProviderContainer buildContainer(List<Deworming> records) {
    final container = ProviderContainer(
      overrides: [
        dewormingRepositoryProvider.overrideWithValue(
          _FakeDewormingRepository(records),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('DewormingsNotifier - orquestación datos + recordatorio', () {
    test('addDeworming agenda con id distinto para cada registro', () async {
      await NotificationService().init();
      final records = <Deworming>[];
      final container = buildContainer(records);
      calls.clear();

      final d1 = Deworming(
        id: const Uuid().v4(),
        petId: 'pet-1',
        product: 'ProductoA',
        date: DateTime.now(),
        nextDate: DateTime.now().add(const Duration(days: 30)),
      );
      final d2 = Deworming(
        id: const Uuid().v4(),
        petId: 'pet-1',
        product: 'ProductoB',
        date: DateTime.now(),
        nextDate: DateTime.now().add(const Duration(days: 45)),
      );

      await container.read(dewormingsProvider('pet-1').notifier).addDeworming(d1);
      await container.read(dewormingsProvider('pet-1').notifier).addDeworming(d2);

      final scheduleCalls =
          calls.where((c) => c.method == 'zonedSchedule').toList();
      expect(scheduleCalls, hasLength(2));

      final ids = scheduleCalls.map((c) => c.arguments['id'] as int).toList();
      expect(
        ids.toSet().length,
        ids.length,
        reason: 'ids repetidos entre dos desparasitaciones distintas',
      );
    });

    test(
      'updateDeworming cancela el id anterior antes de reprogramar el mismo id',
      () async {
        await NotificationService().init();
        final original = Deworming(
          id: const Uuid().v4(),
          petId: 'pet-1',
          product: 'ProductoA',
          date: DateTime.now(),
          nextDate: DateTime.now().add(const Duration(days: 30)),
        );
        final records = <Deworming>[original];
        final container = buildContainer(records);
        calls.clear();

        final updated =
            original.copyWith(nextDate: DateTime.now().add(const Duration(days: 60)));
        await container
            .read(dewormingsProvider('pet-1').notifier)
            .updateDeworming(original, updated);

        final relevantCalls = calls
            .where((c) => c.method == 'cancel' || c.method == 'zonedSchedule')
            .toList();
        expect(relevantCalls, hasLength(2));
        expect(relevantCalls[0].method, 'cancel');
        expect(relevantCalls[1].method, 'zonedSchedule');

        final cancelId = relevantCalls[0].arguments['id'] as int;
        final scheduleId = relevantCalls[1].arguments['id'] as int;
        expect(
          cancelId,
          scheduleId,
          reason: 'mismo id de la desparasitación: no cambia entre ediciones',
        );
      },
    );

    test('deleteDeworming cancela y no vuelve a agendar', () async {
      await NotificationService().init();
      final deworming = Deworming(
        id: const Uuid().v4(),
        petId: 'pet-1',
        product: 'ProductoA',
        date: DateTime.now(),
        nextDate: DateTime.now().add(const Duration(days: 30)),
      );
      final records = <Deworming>[deworming];
      final container = buildContainer(records);
      calls.clear();

      await container.read(dewormingsProvider('pet-1').notifier).deleteDeworming(deworming);

      expect(calls.where((c) => c.method == 'cancel'), hasLength(1));
      expect(calls.where((c) => c.method == 'zonedSchedule'), isEmpty);
    });

    test(
      'agregar muchas desparasitaciones a través del notifier no genera ids repetidos',
      () async {
        await NotificationService().init();
        final records = <Deworming>[];
        final container = buildContainer(records);
        calls.clear();

        for (int i = 0; i < 20; i++) {
          final deworming = Deworming(
            id: const Uuid().v4(),
            petId: 'pet-$i',
            product: 'Producto$i',
            date: DateTime.now(),
            nextDate: DateTime.now().add(Duration(days: 10 + i)),
          );
          await container
              .read(dewormingsProvider('pet-$i').notifier)
              .addDeworming(deworming);
        }

        final ids = calls
            .where((c) => c.method == 'zonedSchedule')
            .map((c) => c.arguments['id'] as int)
            .toList();
        expect(ids, hasLength(20));
        expect(
          ids.toSet().length,
          ids.length,
          reason: 'ids repetidos entre desparasitaciones de distintas mascotas',
        );
      },
    );
  });
}
