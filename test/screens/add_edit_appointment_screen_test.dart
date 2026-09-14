// Tests de widget del flujo "link de Google Maps" en
// AddEditAppointmentScreen (reemplaza la búsqueda de direcciones vía
// Nominatim: la persona busca el lugar en Google Maps, comparte el link, y
// lo pega acá). Usan un LinkLauncher inyectado (parámetro urlLauncher del
// widget) en vez de url_launcher real, para no intentar abrir apps/URLs de
// verdad en flutter test.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/appointment.dart';
import 'package:pet_pal/models/location_entry.dart';
import 'package:pet_pal/providers/appointment_providers.dart';
import 'package:pet_pal/providers/location_entry_providers.dart';
import 'package:pet_pal/repositories/appointment_repository.dart';
import 'package:pet_pal/repositories/location_entry_repository.dart';
import 'package:pet_pal/screens/add_edit_appointment_screen/add_edit_appointment_screen.dart';
import 'package:pet_pal/services/notification_service.dart';

import '../helpers/pump_app.dart';

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

/// Fake en memoria del catálogo de ubicaciones: evita golpear sqflite real
/// -un await directo a IO real dentro del cuerpo de un testWidgets cuelga
/// sin tester.runAsync(), y este dropdown se puebla vía ref.watch dentro
/// del propio widget, donde no hay forma de envolver esa llamada-. La
/// persistencia real del catálogo ya está cubierta en
/// test/repositories/location_entry_repository_test.dart.
class _FakeLocationEntryRepository implements LocationEntryRepository {
  _FakeLocationEntryRepository(this.entries);

  final List<LocationEntry> entries;

  @override
  Future<List<LocationEntry>> getEntries() async {
    final sorted = [...entries]..sort((a, b) => a.name.compareTo(b.name));
    return sorted;
  }

  @override
  Future<void> insertEntry(LocationEntry entry) async {
    entries.add(entry);
  }

  @override
  Future<void> updateEntry(LocationEntry entry) async {
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index != -1) entries[index] = entry;
  }

  @override
  Future<void> deleteEntry(String id) async {
    entries.removeWhere((e) => e.id == id);
  }
}

/// Mismo wrapper de Navigator real de un solo nivel que ya usa el último
/// test de "link de Google Maps" -Navigator.of(context).pop() al final de
/// _saveAppointment necesita una ruta anterior a la cual volver-. Se
/// reutiliza acá porque los tres tests del catálogo de ubicaciones abajo
/// también guardan la cita hasta el final.
Future<void> _pumpFormWithNavigator(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AddEditAppointmentScreen(petId: 'pet-1'),
              ),
            ),
            child: const Text('abrir formulario'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir formulario'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('dexterous.com/flutter/local_notifications');

  late Directory tempDbDir;

  setUpAll(() async {
    AndroidFlutterLocalNotificationsPlugin.registerWith();

    // ReminderScheduler.scheduleAppointmentReminder llama a
    // DatabaseHelper().getPetById (vía _petDisplayName) para armar el
    // título de la notificación. Sin esto, ese canal de sqflite real queda
    // sin ningún handler dentro del binding de testWidgets y la espera de
    // esa respuesta nunca se resuelve -a diferencia de los tests planos
    // (test(), no testWidgets()) de appointment_providers_test.dart, que sí
    // toleran ese mismo canal sin inicializar-. Directorio propio, mismo
    // motivo que el resto de los tests que usan sqflite_common_ffi: evitar
    // "database is locked" con otros archivos en paralelo.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDbDir = await Directory.systemTemp.createTemp('add_edit_appointment_screen_test_db_');
    // ignore: deprecated_member_use
    await databaseFactory.setDatabasesPath(tempDbDir.path);
  });

  tearDownAll(() async {
    try {
      if (await tempDbDir.exists()) await tempDbDir.delete(recursive: true);
    } catch (_) {
      // Mejor esfuerzo, no crítico: ver mismo comentario en database_helper_test.dart.
    }
  });

  setUp(() async {
    await DatabaseHelper().deleteAllData();
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
    // NotificationService().init() acá (setUp corre en una zona async
    // normal), no dentro del cuerpo de un testWidgets: llamarlo ahí, antes
    // del primer pump, cuelga para siempre -AutomatedTestWidgetsFlutterBinding
    // controla el tiempo manualmente dentro de testWidgets, y nada empuja
    // esa cola de microtasks/timers hasta el primer pump()-.
    await NotificationService().init();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('AddEditAppointmentScreen - link de Google Maps', () {
    testWidgets(
      'pegar un link válido y presionar "Abrir en Maps" intenta abrir la URL correcta',
      (tester) async {
        Uri? openedUri;

        await pumpApp(
          tester,
          AddEditAppointmentScreen(
            petId: 'pet-1',
            urlLauncher: (uri) async {
              openedUri = uri;
              return true;
            },
          ),
        );

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Enlace de Google Maps (opcional)'),
          'https://maps.app.goo.gl/AbCdEfGh',
        );
        await tester.pump();

        expect(find.text('Abrir en Maps'), findsOneWidget,
            reason: 'con un link pegado, el botón debe aparecer');

        // El SegmentedButton "guardados"/"nuevo" hizo crecer el formulario:
        // sin desplazar el scroll primero, este botón queda fuera del
        // viewport por defecto (800x600).
        await tester.ensureVisible(find.text('Abrir en Maps'));
        await tester.tap(find.text('Abrir en Maps'));
        await tester.pump();

        expect(openedUri, Uri.parse('https://maps.app.goo.gl/AbCdEfGh'));
      },
    );

    testWidgets(
      'si url_launcher no puede abrir el link, muestra un SnackBar amigable (sin tecnicismos)',
      (tester) async {
        await pumpApp(
          tester,
          AddEditAppointmentScreen(
            petId: 'pet-1',
            urlLauncher: (uri) async => false,
          ),
        );

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Enlace de Google Maps (opcional)'),
          'https://maps.app.goo.gl/roto',
        );
        await tester.pump();

        await tester.ensureVisible(find.text('Abrir en Maps'));
        await tester.tap(find.text('Abrir en Maps'));
        await tester.pump();

        expect(find.text('No se pudo abrir el enlace.'), findsOneWidget);
      },
    );

    testWidgets(
      'sin ningún link pegado, no se muestra el botón "Abrir en Maps"',
      (tester) async {
        await pumpApp(
          tester,
          const AddEditAppointmentScreen(petId: 'pet-1'),
        );

        expect(find.text('Abrir en Maps'), findsNothing);
      },
    );

    testWidgets(
      'un link que no parece una URL válida no bloquea el formulario: la cita '
      'se guarda igual',
      (tester) async {
        final records = <Appointment>[];
        final container = ProviderContainer(
          overrides: [
            appointmentRepositoryProvider.overrideWithValue(
              _FakeAppointmentRepository(records),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Con un Navigator real de un solo nivel (mismo uso real: esta
        // pantalla siempre se abre con Navigator.push desde otra), en vez
        // de home directo -Navigator.of(context).pop() al final de
        // _saveAppointment necesita una ruta anterior a la cual volver;
        // sin ella, pop() sobre la única ruta cuelga el pumpAndSettle de
        // más abajo esperando un asentamiento que nunca llega.
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AddEditAppointmentScreen(petId: 'pet-1'),
                    ),
                  ),
                  child: const Text('abrir formulario'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('abrir formulario'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Título de la Cita'),
          'Control anual',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Enlace de Google Maps (opcional)'),
          'esto no es un link',
        );
        await tester.pump();

        // El texto de ayuda discreto aparece, pero nada bloquea el guardado.
        expect(find.text('Pega el enlace que compartiste desde Google Maps.'), findsOneWidget);

        // El formulario creció con los campos nuevos: el botón queda fuera
        // del viewport por defecto (800x600) sin desplazar el scroll primero.
        final Finder saveButton = find.widgetWithText(ElevatedButton, 'Guardar Cita');
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        expect(
          records,
          hasLength(1),
          reason: 'la cita debe guardarse aunque el link no parezca una URL válida',
        );
        expect(records.single.locationMapsUrl, 'esto no es un link');
        expect(find.text('Revisa los campos marcados en rojo antes de guardar.'), findsNothing);
      },
    );
  });

  group('AddEditAppointmentScreen - catálogo de ubicaciones', () {
    testWidgets(
      'copia congelada: elegir un lugar del catálogo y editarlo después no '
      'afecta a la cita ya guardada',
      (tester) async {
        final catalogEntries = [
          LocationEntry(
            id: 'entry-1',
            name: 'Veterinaria Central',
            mapsUrl: 'https://maps.app.goo.gl/original',
          ),
        ];

        final records = <Appointment>[];
        final container = ProviderContainer(
          overrides: [
            appointmentRepositoryProvider.overrideWithValue(_FakeAppointmentRepository(records)),
            locationEntryRepositoryProvider
                .overrideWithValue(_FakeLocationEntryRepository(catalogEntries)),
          ],
        );
        addTearDown(container.dispose);

        await _pumpFormWithNavigator(tester, container);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Título de la Cita'),
          'Control anual',
        );

        await tester.tap(find.text('Elegir de mis lugares guardados'));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Veterinaria Central').last);
        await tester.pumpAndSettle();

        final Finder saveButton = find.widgetWithText(ElevatedButton, 'Guardar Cita');
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        expect(records, hasLength(1));
        expect(records.single.location, 'Veterinaria Central');
        expect(records.single.locationMapsUrl, 'https://maps.app.goo.gl/original');

        // Editar la entrada del catálogo DESPUÉS de haber guardado la cita
        // (a través del mismo notifier que usaría LocationEntriesScreen).
        await container.read(locationEntriesProvider.notifier).updateEntry(
              LocationEntry(
                id: 'entry-1',
                name: 'Veterinaria Central (mudada)',
                mapsUrl: 'https://maps.app.goo.gl/nueva',
              ),
            );

        // La copia congelada en la cita ya guardada no cambia.
        expect(records.single.location, 'Veterinaria Central');
        expect(records.single.locationMapsUrl, 'https://maps.app.goo.gl/original');
      },
    );

    testWidgets(
      'checkbox "Guardar en mi catálogo de lugares" agrega la entrada al catálogo al guardar',
      (tester) async {
        final records = <Appointment>[];
        final catalogEntries = <LocationEntry>[];
        final container = ProviderContainer(
          overrides: [
            appointmentRepositoryProvider.overrideWithValue(_FakeAppointmentRepository(records)),
            locationEntryRepositoryProvider
                .overrideWithValue(_FakeLocationEntryRepository(catalogEntries)),
          ],
        );
        addTearDown(container.dispose);

        await _pumpFormWithNavigator(tester, container);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Título de la Cita'),
          'Control anual',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Lugar (Opcional)'),
          'Veterinaria Nueva',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Enlace de Google Maps (opcional)'),
          'https://maps.app.goo.gl/nueva-vet',
        );
        await tester.pump();

        await tester.ensureVisible(find.text('Guardar en mi catálogo de lugares'));
        await tester.tap(find.text('Guardar en mi catálogo de lugares'));
        await tester.pump();

        final Finder saveButton = find.widgetWithText(ElevatedButton, 'Guardar Cita');
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        expect(records, hasLength(1));
        expect(catalogEntries, hasLength(1));
        expect(catalogEntries.single.name, 'Veterinaria Nueva');
        expect(catalogEntries.single.mapsUrl, 'https://maps.app.goo.gl/nueva-vet');
      },
    );

    testWidgets(
      '"nuevo" sin marcar el checkbox no agrega nada al catálogo',
      (tester) async {
        final records = <Appointment>[];
        final catalogEntries = <LocationEntry>[];
        final container = ProviderContainer(
          overrides: [
            appointmentRepositoryProvider.overrideWithValue(_FakeAppointmentRepository(records)),
            locationEntryRepositoryProvider
                .overrideWithValue(_FakeLocationEntryRepository(catalogEntries)),
          ],
        );
        addTearDown(container.dispose);

        await _pumpFormWithNavigator(tester, container);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Título de la Cita'),
          'Control anual',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Lugar (Opcional)'),
          'Veterinaria Sin Guardar',
        );

        final Finder saveButton = find.widgetWithText(ElevatedButton, 'Guardar Cita');
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        expect(records, hasLength(1));
        expect(catalogEntries, isEmpty);
      },
    );
  });
}
