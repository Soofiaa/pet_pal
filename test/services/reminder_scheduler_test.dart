// Pruebas de ReminderScheduler: la propiedad real de "sin colisión de IDs"
// vive acá, no en NotificationService. NotificationService solo agenda con
// el id que se le pasa; ReminderScheduler es quien decide, por ejemplo, que
// cada (medicación, horario, día) tenga un id distinto (ver
// _medicationTimedDayId). Un test que solo ejercite NotificationService
// pasaría siempre, sin importar si ese esquema de ids tiene un bug real.
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_pal/models/deworming.dart';
import 'package:pet_pal/models/medication.dart';
import 'package:pet_pal/models/vaccination.dart';
import 'package:pet_pal/services/notification_service.dart';
import 'package:pet_pal/services/reminder_scheduler.dart';
import 'package:uuid/uuid.dart';

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

  List<DateTime> scheduledDateTimes() => calls
      .where((c) => c.method == 'zonedSchedule')
      .map((c) => DateTime.parse(c.arguments['scheduledDateTime'] as String))
      .toList();

  group('ReminderScheduler - IDs sin colisión', () {
    test(
      'una medicación con varios horarios y rango de días agenda exactamente '
      'horarios × días notificaciones, todas con id distinto',
      () async {
        await NotificationService().init();
        calls.clear();

        final DateTime startDate = DateTime.now().add(const Duration(days: 1));
        final DateTime endDate = startDate.add(const Duration(days: 2)); // rango inclusivo: 3 días

        final medication = Medication(
          id: const Uuid().v4(),
          petId: 'pet-1',
          name: 'Antibiótico',
          dosage: '1 comprimido',
          frequency: 'Cada 8 horas',
          notes: '',
          startDate: startDate,
          endDate: endDate,
          reminderTimes: const ['08:00', '16:00'],
        );

        await ReminderScheduler.scheduleMedicationReminders(medication);

        final ids = scheduledIds();
        // 2 horarios x 3 días (inclusive) = 6 notificaciones.
        expect(ids, hasLength(6));
        expect(
          ids.toSet().length,
          ids.length,
          reason: 'ids repetidos entre horarios/días de la misma medicación',
        );
      },
    );

    test(
      'muchas medicaciones distintas con varios horarios no colisionan entre sí',
      () async {
        await NotificationService().init();
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
            endDate: startDate.add(const Duration(days: 4)),
            reminderTimes: const ['08:00', '20:00'],
          );
          await ReminderScheduler.scheduleMedicationReminders(medication);
        }

        final ids = scheduledIds();
        expect(ids, isNotEmpty);
        expect(
          ids.toSet().length,
          ids.length,
          reason: 'ids de zonedSchedule repetidos entre distintas medicaciones',
        );
      },
    );

    test(
      'vacuna, desparasitación y medicación de la misma mascota no colisionan',
      () async {
        await NotificationService().init();
        calls.clear();

        const String petId = 'pet-1';
        final DateTime future = DateTime.now().add(const Duration(days: 30));

        await ReminderScheduler.scheduleVaccinationReminder(Vaccination(
          petId: petId,
          vaccineName: 'Rabia',
          date: DateTime.now(),
          nextDueDate: future,
        ));

        await ReminderScheduler.scheduleDewormingReminder(Deworming(
          id: const Uuid().v4(),
          petId: petId,
          product: 'ProductoX',
          date: DateTime.now(),
          nextDate: future,
        ));

        await ReminderScheduler.scheduleMedicationReminders(Medication(
          id: const Uuid().v4(),
          petId: petId,
          name: 'MedX',
          dosage: '1',
          frequency: 'x',
          notes: '',
          startDate: DateTime.now().add(const Duration(days: 1)),
          endDate: DateTime.now().add(const Duration(days: 3)),
          reminderTimes: const ['09:00'],
        ));

        final ids = scheduledIds();
        // Al menos 1 (vacuna) + 1 (desparasitación) + N (medicación).
        expect(ids.length, greaterThanOrEqualTo(3));
        expect(ids.toSet().length, ids.length);
      },
    );

    test(
      'reprogramar la misma medicación (cancelar + reagendar) usa los '
      'mismos ids, sin dejar huérfanos con ids nuevos',
      () async {
        await NotificationService().init();
        calls.clear();

        final String medicationId = const Uuid().v4();
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

        await ReminderScheduler.scheduleMedicationReminders(medication);
        final firstRunIds = scheduledIds().toSet();
        calls.clear();

        await ReminderScheduler.cancelMedicationReminders(medication);
        await ReminderScheduler.scheduleMedicationReminders(medication);
        final secondRunIds = scheduledIds().toSet();

        expect(
          secondRunIds,
          equals(firstRunIds),
          reason:
              'reprogramar la misma medicación sin cambios debería reusar '
              'exactamente los mismos ids (idempotente), no generar otros nuevos',
        );
      },
    );
  });

  group('ReminderScheduler - desparasitación recurrente', () {
    test(
      'un registro recurrente vencido hace meses se programa en la próxima '
      'ocurrencia futura, no en la fecha vieja guardada',
      () async {
        await NotificationService().init();
        calls.clear();

        // nextDate vencido hace ~4 meses, ciclo de 1 mes: la próxima
        // ocurrencia futura real cae bastante después de nextDate.
        final DateTime staleNextDate =
            DateTime.now().subtract(const Duration(days: 120));

        await ReminderScheduler.scheduleDewormingReminder(Deworming(
          id: const Uuid().v4(),
          petId: 'pet-1',
          product: 'ProductoRecurrente',
          date: staleNextDate.subtract(const Duration(days: 30)),
          nextDate: staleNextDate,
          frequencyMonths: 1,
          isRecurring: true,
        ));

        final dateTimes = scheduledDateTimes();
        expect(dateTimes, hasLength(1));
        expect(
          dateTimes.single.isAfter(DateTime.now()),
          isTrue,
          reason: 'debe reprogramarse a futuro, no quedarse en la fecha vencida',
        );
      },
    );

    test(
      'un registro NO recurrente vencido no se programa (comportamiento sin '
      'cambios: NotificationService ya evita agendar en el pasado; sin '
      'isRecurring, effectiveNextDate no avanza la fecha vieja)',
      () async {
        await NotificationService().init();
        calls.clear();

        final DateTime staleNextDate =
            DateTime.now().subtract(const Duration(days: 120));

        await ReminderScheduler.scheduleDewormingReminder(Deworming(
          id: const Uuid().v4(),
          petId: 'pet-1',
          product: 'ProductoUnico',
          date: staleNextDate.subtract(const Duration(days: 30)),
          nextDate: staleNextDate,
          frequencyMonths: 1,
          isRecurring: false,
        ));

        expect(scheduledDateTimes(), isEmpty);
      },
    );
  });
}
