// Pruebas de AppointmentsNotifier: la orquestación datos + recordatorio es
// código NUEVO (antes vivía duplicada e inconsistente en tres lugares -
// add_edit_appointment_screen.dart, appointments_screen.dart y
// reminder_scheduler.dart-), así que reminder_scheduler_test.dart no la
// cubre -esa suite prueba que ReminderScheduler en sí mismo no colisiona,
// no que el notifier lo llame con los argumentos y el orden correctos-.
// Mismo patrón que deworming_providers_test.dart: repository fake en
// memoria + canal mockeado de flutter_local_notifications.
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pet_pal/models/appointment.dart';
import 'package:pet_pal/providers/appointment_providers.dart';
import 'package:pet_pal/repositories/appointment_repository.dart';
import 'package:pet_pal/services/notification_service.dart';
import 'package:uuid/uuid.dart';

class _FakeAppointmentRepository implements AppointmentRepository {
  _FakeAppointmentRepository(this.records);

  final List<Appointment> records;

  @override
  Future<List<Appointment>> getAppointmentsForPet(String petId) async {
    return records.where((r) => r.petId == petId).toList();
  }

  @override
  Future<void> insertAppointment(Appointment appointment) async {
    records.add(appointment);
  }

  @override
  Future<void> updateAppointment(Appointment appointment) async {
    final index = records.indexWhere((r) => r.id == appointment.id);
    if (index != -1) records[index] = appointment;
  }

  @override
  Future<void> deleteAppointment(String id) async {
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

  ProviderContainer buildContainer(List<Appointment> records) {
    final container = ProviderContainer(
      overrides: [
        appointmentRepositoryProvider.overrideWithValue(
          _FakeAppointmentRepository(records),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('AppointmentsNotifier - orquestación datos + recordatorio', () {
    test('addAppointment agenda con id distinto para cada registro', () async {
      await NotificationService().init();
      final records = <Appointment>[];
      final container = buildContainer(records);
      calls.clear();

      final a1 = Appointment(
        id: const Uuid().v4(),
        petId: 'pet-1',
        dateTime: DateTime.now().add(const Duration(days: 30)),
        title: 'Cita A',
      );
      final a2 = Appointment(
        id: const Uuid().v4(),
        petId: 'pet-1',
        dateTime: DateTime.now().add(const Duration(days: 45)),
        title: 'Cita B',
      );

      await container.read(appointmentsProvider('pet-1').notifier).addAppointment(a1);
      await container.read(appointmentsProvider('pet-1').notifier).addAppointment(a2);

      final scheduleCalls = calls.where((c) => c.method == 'zonedSchedule').toList();
      expect(scheduleCalls, hasLength(2));

      final ids = scheduleCalls.map((c) => c.arguments['id'] as int).toList();
      expect(
        ids.toSet().length,
        ids.length,
        reason: 'ids repetidos entre dos citas distintas',
      );
    });

    test(
      'updateAppointment cancela el recordatorio anterior antes de reprogramar el mismo id',
      () async {
        await NotificationService().init();
        final original = Appointment(
          id: const Uuid().v4(),
          petId: 'pet-1',
          dateTime: DateTime.now().add(const Duration(days: 30)),
          title: 'Control anual',
        );
        final records = <Appointment>[original];
        final container = buildContainer(records);
        calls.clear();

        final updated = original.copyWith(
          dateTime: DateTime.now().add(const Duration(days: 60)),
        );
        await container
            .read(appointmentsProvider('pet-1').notifier)
            .updateAppointment(original, updated);

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
          reason: 'mismo id de la cita: no cambia entre ediciones',
        );
      },
    );

    test(
      'updateAppointment hacia una fecha pasada cancela el recordatorio viejo '
      'y no agenda uno nuevo (el editado ya no amerita recordatorio)',
      () async {
        await NotificationService().init();
        final original = Appointment(
          id: const Uuid().v4(),
          petId: 'pet-1',
          dateTime: DateTime.now().add(const Duration(days: 30)),
          title: 'Control anual',
        );
        final records = <Appointment>[original];
        final container = buildContainer(records);
        calls.clear();

        final updated = original.copyWith(
          dateTime: DateTime.now().subtract(const Duration(days: 5)),
          isCompleted: true,
        );
        await container
            .read(appointmentsProvider('pet-1').notifier)
            .updateAppointment(original, updated);

        expect(calls.where((c) => c.method == 'cancel'), hasLength(1));
        expect(
          calls.where((c) => c.method == 'zonedSchedule'),
          isEmpty,
          reason: 'una cita movida al pasado y marcada completada no debe volver a agendarse',
        );
      },
    );

    test('deleteAppointment cancela y no vuelve a agendar', () async {
      await NotificationService().init();
      final appointment = Appointment(
        id: const Uuid().v4(),
        petId: 'pet-1',
        dateTime: DateTime.now().add(const Duration(days: 30)),
        title: 'Cita',
      );
      final records = <Appointment>[appointment];
      final container = buildContainer(records);
      calls.clear();

      await container.read(appointmentsProvider('pet-1').notifier).deleteAppointment(appointment);

      expect(calls.where((c) => c.method == 'cancel'), hasLength(1));
      expect(calls.where((c) => c.method == 'zonedSchedule'), isEmpty);
      expect(records, isEmpty);
    });

    test(
      'agregar muchas citas a través del notifier no genera ids repetidos',
      () async {
        await NotificationService().init();
        final records = <Appointment>[];
        final container = buildContainer(records);
        calls.clear();

        for (int i = 0; i < 20; i++) {
          await container.read(appointmentsProvider('pet-1').notifier).addAppointment(
                Appointment(
                  id: const Uuid().v4(),
                  petId: 'pet-1',
                  dateTime: DateTime.now().add(Duration(days: 30 + i)),
                  title: 'Cita $i',
                ),
              );
        }

        final ids = calls
            .where((c) => c.method == 'zonedSchedule')
            .map((c) => c.arguments['id'] as int)
            .toList();
        expect(ids, hasLength(20));
        expect(ids.toSet().length, ids.length, reason: 'ids repetidos entre citas distintas');
      },
    );
  });

  group('AppointmentsNotifier.build - auto-completado de citas vencidas', () {
    test(
      'una cita vencida y no completada se marca isCompleted al cargar la lista',
      () async {
        final overdue = Appointment(
          id: const Uuid().v4(),
          petId: 'pet-1',
          dateTime: DateTime.now().subtract(const Duration(days: 2)),
          title: 'Cita vencida',
        );
        final records = <Appointment>[overdue];
        final container = buildContainer(records);

        final result = await container.read(appointmentsProvider('pet-1').future);

        expect(result.single.isCompleted, isTrue);
        // Se persiste en el repository, no solo en el estado en memoria.
        expect(records.single.isCompleted, isTrue);
      },
    );

    test('una cita futura y no completada no se toca al cargar la lista', () async {
      final future = Appointment(
        id: const Uuid().v4(),
        petId: 'pet-1',
        dateTime: DateTime.now().add(const Duration(days: 2)),
        title: 'Cita futura',
      );
      final records = <Appointment>[future];
      final container = buildContainer(records);

      final result = await container.read(appointmentsProvider('pet-1').future);

      expect(result.single.isCompleted, isFalse);
    });

    test('la lista se devuelve ordenada por fecha ascendente', () async {
      final later = Appointment(
        id: const Uuid().v4(),
        petId: 'pet-1',
        dateTime: DateTime.now().add(const Duration(days: 10)),
        title: 'Más tarde',
      );
      final sooner = Appointment(
        id: const Uuid().v4(),
        petId: 'pet-1',
        dateTime: DateTime.now().add(const Duration(days: 1)),
        title: 'Más pronto',
      );
      final records = <Appointment>[later, sooner];
      final container = buildContainer(records);

      final result = await container.read(appointmentsProvider('pet-1').future);

      expect(result.map((a) => a.title), ['Más pronto', 'Más tarde']);
    });
  });
}
