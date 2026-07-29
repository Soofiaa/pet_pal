// Pruebas de MedicationsNotifier: la orquestación datos + recordatorio es
// código NUEVO (antes vivía inline en add_edit_medications_screen.dart /
// medications_screen.dart), así que reminder_scheduler_test.dart no la
// cubre -esa suite prueba que ReminderScheduler en sí mismo (sus tres
// ramas: legado sin reminderTimes, hash horario×día con endDate, y
// repetible sin endDate) no colisiona, no que el notifier lo invoque con
// los argumentos y el orden correctos-. Esta es la migración con más
// riesgo de colisión de ids de las cuatro (Medicación ya tuvo un bug real
// de colisión en el esquema baseId*10+i que se reemplazó por claves
// hasheadas), así que replica a través del notifier el mismo tipo de
// prueba de estrés que reminder_scheduler_test.dart ya hace directamente
// sobre ReminderScheduler.
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pet_pal/models/medication.dart';
import 'package:pet_pal/providers/medication_providers.dart';
import 'package:pet_pal/repositories/medication_repository.dart';
import 'package:pet_pal/services/notification_service.dart';
import 'package:uuid/uuid.dart';

class _FakeMedicationRepository implements MedicationRepository {
  _FakeMedicationRepository(this.records);

  final List<Medication> records;

  @override
  Future<List<Medication>> getMedicationsForPet(String petId) async {
    return records.where((r) => r.petId == petId).toList();
  }

  @override
  Future<void> insertMedication(Medication medication) async {
    records.add(medication);
  }

  @override
  Future<void> updateMedication(Medication medication) async {
    final index = records.indexWhere((r) => r.id == medication.id);
    if (index != -1) records[index] = medication;
  }

  @override
  Future<void> deleteMedication(String id) async {
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

  List<int> scheduledIds() => calls
      .where((c) => c.method == 'zonedSchedule')
      .map((c) => c.arguments['id'] as int)
      .toList();

  ProviderContainer buildContainer(List<Medication> records) {
    final container = ProviderContainer(
      overrides: [
        medicationRepositoryProvider.overrideWithValue(
          _FakeMedicationRepository(records),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('MedicationsNotifier - rama con endDate (hash horario×día)', () {
    test(
      'muchas medicaciones con varios horarios y rango de días largo, '
      'agregadas a través de addMedication, no generan ids repetidos',
      () async {
        await NotificationService().init();
        final records = <Medication>[];
        final container = buildContainer(records);
        calls.clear();

        final DateTime startDate = DateTime.now().add(const Duration(days: 1));
        final DateTime endDate = startDate.add(const Duration(days: 4)); // 5 días inclusive

        for (int i = 0; i < 25; i++) {
          final medication = Medication(
            id: const Uuid().v4(),
            petId: 'pet-$i',
            name: 'Medicamento $i',
            dosage: '1',
            frequency: 'x',
            notes: '',
            startDate: startDate,
            endDate: endDate,
            reminderTimes: const ['08:00', '20:00'],
          );
          await container
              .read(medicationsProvider('pet-$i').notifier)
              .addMedication(medication);
        }

        final ids = scheduledIds();
        // 25 medicaciones x 2 horarios x 5 días = 250 notificaciones.
        expect(ids, hasLength(250));
        expect(
          ids.toSet().length,
          ids.length,
          reason:
              'ids repetidos entre medicaciones/horarios/días al agendar a '
              'través de MedicationsNotifier.addMedication',
        );
      },
    );
  });

  group('MedicationsNotifier - rama sin endDate (modo repetible)', () {
    test(
      'muchas medicaciones indefinidas con varios horarios, agregadas a '
      'través de addMedication, no generan ids repetidos',
      () async {
        await NotificationService().init();
        final records = <Medication>[];
        final container = buildContainer(records);
        calls.clear();

        final DateTime startDate = DateTime.now().add(const Duration(days: 1));

        for (int i = 0; i < 25; i++) {
          final medication = Medication(
            id: const Uuid().v4(),
            petId: 'pet-$i',
            name: 'Medicamento $i',
            dosage: '1',
            frequency: 'x',
            notes: '',
            startDate: startDate,
            // Sin endDate: modo repetible, una alarma por horario (no por día).
            reminderTimes: const ['08:00', '14:00', '20:00'],
          );
          await container
              .read(medicationsProvider('pet-$i').notifier)
              .addMedication(medication);
        }

        final ids = scheduledIds();
        // 25 medicaciones x 3 horarios = 75 alarmas repetibles (una por horario, no por día).
        expect(ids, hasLength(75));
        expect(
          ids.toSet().length,
          ids.length,
          reason:
              'ids repetidos entre alarmas repetibles de distintas '
              'medicaciones/horarios al agendar a través de '
              'MedicationsNotifier.addMedication',
        );
      },
    );

    test(
      'updateMedication en modo repetible cancela los ids anteriores antes '
      'de reprogramar los mismos ids',
      () async {
        await NotificationService().init();
        final original = Medication(
          id: const Uuid().v4(),
          petId: 'pet-1',
          name: 'MedX',
          dosage: '1',
          frequency: 'x',
          notes: '',
          startDate: DateTime.now().add(const Duration(days: 1)),
          reminderTimes: const ['08:00', '20:00'],
        );
        final container = buildContainer([original]);
        calls.clear();

        // Cambia la dosis, no los horarios ni el startDate: los ids
        // repetibles dependen de (medicationId, timeIndex), así que deben
        // ser los mismos antes y después.
        final updated = original.copyWith(dosage: '2');
        await container
            .read(medicationsProvider('pet-1').notifier)
            .updateMedication(original, updated);

        final cancelIds = calls
            .where((c) => c.method == 'cancel')
            .map((c) => c.arguments['id'] as int)
            .toSet();
        final scheduleIds = scheduledIds().toSet();

        expect(cancelIds, hasLength(2));
        expect(scheduleIds, hasLength(2));
        expect(
          scheduleIds,
          equals(cancelIds),
          reason:
              'reprogramar sin cambiar horarios debería reusar exactamente '
              'los mismos ids repetibles (idempotente)',
        );
      },
    );
  });

  group('MedicationsNotifier - rama legado (reminderTimes vacío)', () {
    test(
      'addMedication y deleteMedication usan el mismo baseId legado',
      () async {
        await NotificationService().init();
        final medication = Medication(
          id: const Uuid().v4(),
          petId: 'pet-1',
          name: 'MedLegado',
          dosage: '1',
          frequency: '',
          notes: '',
          startDate: DateTime.now().add(const Duration(days: 1)),
          endDate: DateTime.now().add(const Duration(days: 3)),
          reminderTimes: const [],
        );
        final records = <Medication>[];
        final container = buildContainer(records);
        calls.clear();

        await container
            .read(medicationsProvider('pet-1').notifier)
            .addMedication(medication);

        final scheduledLegacyIds = scheduledIds().toSet();
        expect(scheduledLegacyIds, isNotEmpty);
        calls.clear();

        await container
            .read(medicationsProvider('pet-1').notifier)
            .deleteMedication(medication);

        final cancelledIds = calls
            .where((c) => c.method == 'cancel')
            .map((c) => c.arguments['id'] as int)
            .toSet();

        expect(
          cancelledIds,
          equals(scheduledLegacyIds),
          reason:
              'deleteMedication debe cancelar exactamente los mismos ids '
              'legados (baseId*1000+día) que addMedication programó',
        );
      },
    );
  });

  group('MedicationsNotifier - reprogramar rama con endDate es idempotente', () {
    test(
      'reprogramar la misma medicación (cancelar + reagendar) a través de '
      'updateMedication usa los mismos ids, sin dejar huérfanos con ids nuevos',
      () async {
        await NotificationService().init();
        final medicationId = const Uuid().v4();
        final DateTime startDate = DateTime.now().add(const Duration(days: 1));

        final medication = Medication(
          id: medicationId,
          petId: 'pet-1',
          name: 'MedX',
          dosage: '1',
          frequency: 'x',
          notes: '',
          startDate: startDate,
          endDate: startDate.add(const Duration(days: 2)),
          reminderTimes: const ['08:00', '20:00'],
        );
        final container = buildContainer([medication]);
        calls.clear();

        // Actualiza sin cambiar fechas ni horarios: mismo shape que el
        // registro original, para poder comparar el set de ids exactamente.
        final updated = medication.copyWith(dosage: '2');
        await container
            .read(medicationsProvider('pet-1').notifier)
            .updateMedication(medication, updated);

        final firstScheduleIds = scheduledIds().toSet();
        calls.clear();

        final updatedAgain = updated.copyWith(dosage: '3');
        await container
            .read(medicationsProvider('pet-1').notifier)
            .updateMedication(updated, updatedAgain);

        final secondScheduleIds = scheduledIds().toSet();

        expect(
          secondScheduleIds,
          equals(firstScheduleIds),
          reason:
              'reprogramar la misma medicación sin cambiar fechas/horarios '
              'debería reusar exactamente los mismos ids (idempotente)',
        );
      },
    );
  });
}
