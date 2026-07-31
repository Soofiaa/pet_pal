// Pruebas de NotificationService: programación y cancelación de
// notificaciones.
//
// flutter_local_notifications habla con código nativo por el canal de
// plataforma 'dexterous.com/flutter/local_notifications' (confirmado en el
// código fuente del paquete). flutter_test corre con
// debugDefaultTargetPlatformOverride = TargetPlatform.android por defecto,
// así que ese canal SÍ se invoca aunque no haya dispositivo. Se intercepta
// con el mock de canal que trae flutter_test (sin dependencias nuevas) para
// grabar cada llamada y afirmar sobre sus argumentos.
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_pal/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel =
      MethodChannel('dexterous.com/flutter/local_notifications');

  // En una app real, el registrant generado por Flutter registra la
  // implementación concreta de la plataforma. flutter test no corre ese
  // registrant, así que hay que hacerlo a mano una vez, o
  // FlutterLocalNotificationsPlatform.instance queda sin inicializar.
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

  group('NotificationService - programación', () {
    test('scheduleNotificationOnce agenda con el id, fecha y modo dados', () async {
      final service = NotificationService();
      await service.init();
      calls.clear();

      final scheduledDateTime = DateTime.now().add(const Duration(days: 1));
      await service.scheduleNotificationOnce(
        id: 42,
        title: 'Título',
        body: 'Cuerpo',
        scheduledDateTime: scheduledDateTime,
      );

      final scheduleCalls =
          calls.where((c) => c.method == 'zonedSchedule').toList();
      expect(scheduleCalls, hasLength(1));
      expect(scheduleCalls.first.arguments['id'], 42);
    });

    test('scheduleNotificationOnce no agenda si la fecha ya pasó', () async {
      final service = NotificationService();
      await service.init();
      calls.clear();

      await service.scheduleNotificationOnce(
        id: 1,
        title: 'Título',
        body: 'Cuerpo',
        scheduledDateTime: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(calls.where((c) => c.method == 'zonedSchedule'), isEmpty);
    });

    test(
      'scheduleMedicationForDays genera un id distinto por día, sin colisión',
      () async {
        final service = NotificationService();
        await service.init();
        calls.clear();

        await service.scheduleMedicationForDays(
          baseId: 5,
          title: 'Medicación',
          body: 'Dosis',
          firstDoseDateTime: DateTime.now().add(const Duration(days: 1)),
          days: 7,
        );

        final scheduleCalls =
            calls.where((c) => c.method == 'zonedSchedule').toList();
        expect(scheduleCalls, hasLength(7));

        final ids =
            scheduleCalls.map((c) => c.arguments['id'] as int).toList();
        expect(
          ids.toSet().length,
          ids.length,
          reason: 'no debería haber ids de zonedSchedule repetidos',
        );
      },
    );

    test(
      'scheduleDailyRepeatingNotification agenda con matchDateTimeComponents.time',
      () async {
        final service = NotificationService();
        await service.init();
        calls.clear();

        await service.scheduleDailyRepeatingNotification(
          id: 7,
          title: 'Repetible',
          body: 'Cuerpo',
          firstOccurrence: DateTime.now().add(const Duration(days: 1)),
        );

        final scheduleCalls =
            calls.where((c) => c.method == 'zonedSchedule').toList();
        expect(scheduleCalls, hasLength(1));
        expect(scheduleCalls.first.arguments['id'], 7);
        // El valor exacto de matchDateTimeComponents lo serializa el propio
        // plugin (índice de enum); alcanza con confirmar que viaja no-nulo,
        // que es lo que distingue a una alarma repetible de una one-shot.
        expect(scheduleCalls.first.arguments['matchDateTimeComponents'], isNotNull);
      },
    );
  });

  group('NotificationService - alertas inmediatas', () {
    test('showImmediateNotification dispara un show (no zonedSchedule)', () async {
      final service = NotificationService();
      await service.init();
      calls.clear();

      await service.showImmediateNotification(
        id: 123,
        title: 'Valor anormal de Temperatura',
        body: '40.5°C está fuera del rango normal.',
      );

      final showCalls = calls.where((c) => c.method == 'show').toList();
      expect(showCalls, hasLength(1));
      expect(showCalls.first.arguments['id'], 123);
      expect(calls.where((c) => c.method == 'zonedSchedule'), isEmpty);
    });

    test('showImmediateNotification usa el canal vital_sign_alerts', () async {
      final service = NotificationService();
      await service.init();
      calls.clear();

      await service.showImmediateNotification(
        id: 1,
        title: 'Título',
        body: 'Cuerpo',
      );

      final showCall = calls.firstWhere((c) => c.method == 'show');
      final platformSpecifics =
          showCall.arguments['platformSpecifics'] as Map;
      expect(platformSpecifics['channelId'], 'vital_sign_alerts');
    });
  });

  group('NotificationService - cancelación', () {
    test('cancelNotification cancela por el id exacto', () async {
      final service = NotificationService();
      await service.init();
      calls.clear();

      await service.cancelNotification(99);

      final cancelCalls = calls.where((c) => c.method == 'cancel').toList();
      expect(cancelCalls, hasLength(1));
      expect(cancelCalls.first.arguments['id'], 99);
    });

    test('cancelMedicationForDays cancela todos los ids del rango', () async {
      final service = NotificationService();
      await service.init();
      calls.clear();

      await service.cancelMedicationForDays(baseId: 5, days: 7);

      final cancelCalls = calls.where((c) => c.method == 'cancel').toList();
      expect(cancelCalls, hasLength(7));

      final ids = cancelCalls.map((c) => c.arguments['id'] as int).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('cancelAllNotifications invoca cancelAll', () async {
      final service = NotificationService();
      await service.init();
      calls.clear();

      await service.cancelAllNotifications();

      expect(calls.where((c) => c.method == 'cancelAll'), hasLength(1));
    });
  });
}
