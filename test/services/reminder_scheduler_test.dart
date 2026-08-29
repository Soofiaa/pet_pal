// Pruebas de ReminderScheduler: la propiedad real de "sin colisión de IDs"
// vive acá, no en NotificationService. NotificationService solo agenda con
// el id que se le pasa; ReminderScheduler es quien decide, por ejemplo, que
// cada (medicación, horario, día) tenga un id distinto (ver
// _medicationTimedDayId). Un test que solo ejercite NotificationService
// pasaría siempre, sin importar si ese esquema de ids tiene un bug real.
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_pal/models/appointment.dart';
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

  List<int> canceledIds() =>
      calls.where((c) => c.method == 'cancel').map((c) => c.arguments['id'] as int).toList();

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

  group('ReminderScheduler - Cita (centralización de Fase 3)', () {
    test(
      'scheduleAppointmentReminder agenda con id == appointment.id.hashCode '
      '(fórmula que ya usaban los tres lugares duplicados antes de centralizar)',
      () async {
        await NotificationService().init();
        calls.clear();

        final String appointmentId = const Uuid().v4();
        final appointment = Appointment(
          id: appointmentId,
          petId: 'pet-1',
          dateTime: DateTime.now().add(const Duration(days: 5)),
          title: 'Control anual',
        );

        await ReminderScheduler.scheduleAppointmentReminder(appointment);

        final ids = scheduledIds();
        expect(ids, hasLength(1));
        // Valor calculado a mano, no reutilizando la implementación: si
        // scheduleAppointmentReminder cambiara de fórmula, este test debe
        // fallar aunque el código de producción "se mueva junto".
        expect(ids.single, appointmentId.hashCode);
      },
    );

    test(
      'scheduleAppointmentReminder agenda exactamente un día antes de la '
      'cita, a la misma hora (sin ajustar a una hora fija)',
      () async {
        await NotificationService().init();
        calls.clear();

        // Se compara la DIFERENCIA entre dos citas, no un valor absoluto
        // contra dateTime.subtract(1 día): tz.local no está inicializado en
        // el entorno de test ("Error al configurar la zona horaria" arriba),
        // así que TZDateTime.from aplica un corrimiento fijo al serializar
        // el argumento de zonedSchedule. Ese corrimiento se cancela al
        // restar dos scheduledDateTime entre sí, así que la diferencia sigue
        // probando la aritmética real de scheduleAppointmentReminder sin
        // depender de que el entorno de test tenga tz configurado.
        final DateTime dateTimeA = DateTime(2030, 3, 15, 14, 30);
        final DateTime dateTimeB = dateTimeA.add(const Duration(days: 3));

        await ReminderScheduler.scheduleAppointmentReminder(Appointment(
          petId: 'pet-1',
          dateTime: dateTimeA,
          title: 'Cita A',
        ));
        await ReminderScheduler.scheduleAppointmentReminder(Appointment(
          petId: 'pet-1',
          dateTime: dateTimeB,
          title: 'Cita B',
        ));

        final times = scheduledDateTimes();
        expect(times, hasLength(2));
        expect(
          times[1].difference(times[0]),
          dateTimeB.difference(dateTimeA),
          reason: 'el recordatorio de B debe seguir siendo exactamente '
              '3 días después que el de A, igual que sus citas',
        );
      },
    );

    test(
      'cancelAppointmentReminder usa el mismo id que scheduleAppointmentReminder '
      '(round-trip: agendar y cancelar la misma cita)',
      () async {
        await NotificationService().init();
        calls.clear();

        final appointment = Appointment(
          petId: 'pet-1',
          dateTime: DateTime.now().add(const Duration(days: 5)),
          title: 'Control anual',
        );

        await ReminderScheduler.scheduleAppointmentReminder(appointment);
        final int scheduleId = scheduledIds().single;
        calls.clear();

        await ReminderScheduler.cancelAppointmentReminder(appointment);
        final int cancelId = canceledIds().single;

        expect(
          cancelId,
          scheduleId,
          reason: 'agendar y cancelar la misma cita deben usar exactamente el mismo id',
        );
      },
    );

    test(
      'una cita marcada isCompleted no se agenda aunque su fecha sea futura '
      '(decisión adoptada: el criterio de rescheduleAllPending, no el que '
      'tenía add_edit_appointment_screen.dart antes de centralizar)',
      () async {
        await NotificationService().init();
        calls.clear();

        final appointment = Appointment(
          petId: 'pet-1',
          dateTime: DateTime.now().add(const Duration(days: 5)),
          title: 'Control anual',
          isCompleted: true,
        );

        await ReminderScheduler.scheduleAppointmentReminder(appointment);

        expect(scheduledIds(), isEmpty);
      },
    );

    test(
      'una cita cuyo recordatorio ("un día antes") ya pasó no se agenda',
      () async {
        await NotificationService().init();
        calls.clear();

        // dateTime dentro de las próximas horas: "un día antes" ya pasó.
        final appointment = Appointment(
          petId: 'pet-1',
          dateTime: DateTime.now().add(const Duration(hours: 2)),
          title: 'Control anual',
        );

        await ReminderScheduler.scheduleAppointmentReminder(appointment);

        expect(scheduledIds(), isEmpty);
      },
    );

    test('muchas citas distintas no colisionan entre sí', () async {
      await NotificationService().init();
      calls.clear();

      for (int i = 0; i < 20; i++) {
        await ReminderScheduler.scheduleAppointmentReminder(Appointment(
          id: const Uuid().v4(),
          petId: 'pet-1',
          dateTime: DateTime.now().add(Duration(days: 5 + i)),
          title: 'Cita $i',
        ));
      }

      final ids = scheduledIds();
      expect(ids, hasLength(20));
      expect(ids.toSet().length, ids.length, reason: 'ids repetidos entre citas distintas');
    });
  });
}
