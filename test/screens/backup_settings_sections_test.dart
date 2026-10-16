import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_pal/screens/backup_settings_screen/backup_settings_screen.dart';
import 'package:pet_pal/services/notification_service.dart';

import '../helpers/pump_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');

  setUpAll(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
  });

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
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
    // Fuera del cuerpo de testWidgets: ver add_edit_appointment_screen_test.dart.
    await NotificationService().init();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('la sección de notificaciones no muestra opciones de respaldo', (tester) async {
    await pumpApp(
      tester,
      const BackupSettingsScreen(section: BackupSettingsSection.notifications),
    );
    await tester.pump();

    expect(find.text('Notificaciones habilitadas'), findsOneWidget);
    expect(find.text('Crear respaldo ZIP'), findsNothing);
    expect(find.text('Restaurar respaldo'), findsNothing);
  });

  testWidgets('la sección de respaldo no muestra permisos de notificaciones', (tester) async {
    await pumpApp(
      tester,
      const BackupSettingsScreen(section: BackupSettingsSection.backup),
    );
    await tester.pump();

    expect(find.text('Crear respaldo ZIP'), findsOneWidget);
    expect(find.text('Restaurar respaldo'), findsWidgets);
    expect(find.text('Notificaciones habilitadas'), findsNothing);
    expect(find.textContaining('Pendiente futuro'), findsNothing);
  });
}
