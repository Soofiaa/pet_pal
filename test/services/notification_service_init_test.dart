// Pedir el permiso de alarmas exactas dentro de init() abría los ajustes del
// sistema en el primer arranque, sin contexto. Ahora solo se pide desde la
// pantalla de Respaldo (requestExactAlarmsPermission), a pedido de la persona.
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pet_pal/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  late List<String> calls;

  setUp(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call.method);
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('init no abre el permiso de alarmas exactas', () async {
    await NotificationService().init();

    expect(calls, contains('requestNotificationsPermission'));
    expect(calls, isNot(contains('requestExactAlarmsPermission')));
  });

  test('requestExactAlarmsPermission sigue disponible a pedido explícito', () async {
    await NotificationService().requestExactAlarmsPermission();

    expect(calls, contains('requestExactAlarmsPermission'));
  });
}
