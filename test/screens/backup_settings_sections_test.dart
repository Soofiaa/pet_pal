import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pet_pal/screens/backup_settings_screen/backup_settings_screen.dart';
import 'package:pet_pal/services/notification_service.dart';

import '../helpers/pump_app.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsDir);

  final Directory documentsDir;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsDir.path;
}

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
    expect(find.text('Archivos antiguos sin uso'), findsNothing);
  });

  group('cuarentena de archivos huérfanos', () {
    late Directory root;
    late Directory filesDir;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('backup_quarantine_ui_');
      final documents = Directory(p.join(root.path, 'documents'))..createSync();
      filesDir = Directory(p.join(documents.path, 'petpal_files'))..createSync();
      PathProviderPlatform.instance = _FakePathProvider(documents);
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    Future<void> pumpBackup(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        await pumpApp(
          tester,
          const BackupSettingsScreen(section: BackupSettingsSection.backup),
        );
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();
    }

    testWidgets('con archivos en cuarentena muestra la tarjeta y permite borrarlos', (tester) async {
      final file = File(p.join(filesDir.path, '_huerfanos_1', 'a.jpg'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(List.filled(2048, 1));

      await pumpBackup(tester);

      expect(find.text('Archivos antiguos sin uso'), findsOneWidget);
      expect(find.textContaining('1 archivos'), findsOneWidget);

      await tester.ensureVisible(find.text('Eliminar archivos antiguos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar archivos antiguos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      for (var i = 0; i < 20 && file.existsSync(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();

      expect(find.textContaining('No se pudieron'), findsNothing);
      expect(file.existsSync(), isFalse);
      expect(find.text('Archivos antiguos eliminados.', skipOffstage: false), findsOneWidget);
    });

    testWidgets('cancelar la confirmación no borra nada', (tester) async {
      final file = File(p.join(filesDir.path, '_huerfanos_1', 'a.jpg'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);

      await pumpBackup(tester);
      await tester.ensureVisible(find.text('Eliminar archivos antiguos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar archivos antiguos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(file.existsSync(), isTrue);
    });
  });
}
