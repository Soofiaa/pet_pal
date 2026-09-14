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
          type: 'interna',
        );
        final records = <Deworming>[original];
        final container = buildContainer(records);
        calls.clear();

        final updated =
            original.copyWith(nextDate: DateTime.now().add(const Duration(days: 60)));
        await container
            .read(dewormingsProvider('pet-1').notifier)
            .updateDeworming(original, updated);

        // La reconciliación posterior a la edición (reconcileDewormingReminders)
        // puede sumar una reprogramación adicional del mismo ganador
        // (idempotente, inofensiva) -lo esencial es que la PRIMERA llamada
        // sea el cancel, y que ninguna reprogramación posterior use un id
        // distinto al cancelado-.
        final relevantCalls = calls
            .where((c) => c.method == 'cancel' || c.method == 'zonedSchedule')
            .toList();
        expect(relevantCalls.length, greaterThanOrEqualTo(2));
        expect(relevantCalls.first.method, 'cancel');

        final cancelId = relevantCalls.first.arguments['id'] as int;
        for (final call in relevantCalls.skip(1)) {
          expect(call.method, 'zonedSchedule',
              reason: 'tras el cancel inicial, solo deberían seguir reprogramaciones');
          expect(
            call.arguments['id'],
            cancelId,
            reason: 'mismo id de la desparasitación: no cambia entre ediciones',
          );
        }
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

    test(
      'addDeworming: agregar un registro "ambas" cancela los recordatorios '
      'de cualquier registro anterior, sin importar su cobertura',
      () async {
        await NotificationService().init();
        final interna = Deworming(
          id: const Uuid().v4(),
          petId: 'pet-1',
          product: 'Desparasitante interno',
          date: DateTime.now().subtract(const Duration(days: 200)),
          nextDate: DateTime.now().add(const Duration(days: 5)),
          type: 'interna',
        );
        final externa = Deworming(
          id: const Uuid().v4(),
          petId: 'pet-1',
          product: 'Simparica',
          date: DateTime.now().subtract(const Duration(days: 100)),
          nextDate: DateTime.now().add(const Duration(days: 20)),
          type: 'externa',
        );
        final container = buildContainer([interna, externa]);
        calls.clear();

        final ambas = Deworming(
          id: const Uuid().v4(),
          petId: 'pet-1',
          product: 'Nexgard Spectra',
          date: DateTime.now(),
          nextDate: DateTime.now().add(const Duration(days: 60)),
          type: 'ambas',
        );
        await container.read(dewormingsProvider('pet-1').notifier).addDeworming(ambas);

        final int internaId = '${interna.id}_next'.hashCode;
        final int externaId = '${externa.id}_next'.hashCode;
        final int ambasId = '${ambas.id}_next'.hashCode;

        final canceledIds =
            calls.where((c) => c.method == 'cancel').map((c) => c.arguments['id'] as int).toSet();
        final scheduledIds = calls
            .where((c) => c.method == 'zonedSchedule')
            .map((c) => c.arguments['id'] as int)
            .toSet();

        expect(canceledIds, containsAll([internaId, externaId]),
            reason: 'un "ambas" nuevo resetea la cobertura completa: ambos registros '
                'anteriores quedan cancelados, sin importar su propio tipo');
        expect(scheduledIds, contains(ambasId));
        expect(scheduledIds.intersection({internaId, externaId}), isEmpty,
            reason: 'solo el "ambas" debe terminar con push activo');
      },
    );

    test(
      'addDeworming: agregar un tipo único nuevo cancela solo el registro '
      'anterior de ESE tipo, sin tocar el del otro tipo',
      () async {
        await NotificationService().init();
        final internaVieja = Deworming(
          id: const Uuid().v4(),
          petId: 'pet-1',
          product: 'Desparasitante interno viejo',
          date: DateTime.now().subtract(const Duration(days: 200)),
          nextDate: DateTime.now().add(const Duration(days: 5)),
          type: 'interna',
        );
        final externaVigente = Deworming(
          id: const Uuid().v4(),
          petId: 'pet-1',
          product: 'Simparica',
          date: DateTime.now().subtract(const Duration(days: 100)),
          nextDate: DateTime.now().add(const Duration(days: 20)),
          type: 'externa',
        );
        final container = buildContainer([internaVieja, externaVigente]);
        calls.clear();

        final internaNueva = Deworming(
          id: const Uuid().v4(),
          petId: 'pet-1',
          product: 'Desparasitante interno nuevo',
          date: DateTime.now(),
          nextDate: DateTime.now().add(const Duration(days: 90)),
          type: 'interna',
        );
        await container.read(dewormingsProvider('pet-1').notifier).addDeworming(internaNueva);

        final int internaViejaId = '${internaVieja.id}_next'.hashCode;
        final int externaVigenteId = '${externaVigente.id}_next'.hashCode;
        final int internaNuevaId = '${internaNueva.id}_next'.hashCode;

        final canceledIds =
            calls.where((c) => c.method == 'cancel').map((c) => c.arguments['id'] as int).toSet();
        final scheduledIds = calls
            .where((c) => c.method == 'zonedSchedule')
            .map((c) => c.arguments['id'] as int)
            .toSet();

        expect(canceledIds, contains(internaViejaId),
            reason: 'el interno viejo perdió su clock ante el interno nuevo');
        expect(scheduledIds, contains(internaNuevaId),
            reason: 'el interno nuevo gana su propio clock');
        expect(scheduledIds, contains(externaVigenteId),
            reason: 'el externo vigente no debe verse afectado por un cambio en el '
                'clock interno -sigue con push activo-');
        expect(canceledIds.contains(externaVigenteId), isFalse,
            reason: 'no debe cancelarse un registro de un tipo de cobertura no relacionado');
      },
    );
  });
}
