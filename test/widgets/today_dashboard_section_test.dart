// Primer widget test del repo (ver BACKLOG.md ítem 2 / Fase 5 del plan de
// implementación): pumpea TodayDashboardSection con todayDashboardProvider
// sobreescrito, sin tocar SQLite real ni providers intermedios.
//
// TodayDashboardSection también observa petsProvider (para showPetName), así
// que también se sobreescribe petRepositoryProvider con un fake en memoria
// -mismo patrón que pets_providers_test.dart-, para que PetsNotifier
// resuelva sin tocar sqflite real.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:pet_pal/models/dashboard_event.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/providers/dashboard_providers.dart';
import 'package:pet_pal/providers/pets_providers.dart';
import 'package:pet_pal/repositories/pet_repository.dart';
import 'package:pet_pal/screens/appointments_screen/appointments_screen.dart';
import 'package:pet_pal/screens/deworming_screen/deworming_screen.dart';
import 'package:pet_pal/screens/medications_screen/medications_screen.dart';
import 'package:pet_pal/screens/vaccinations_screen/vaccinations_screen.dart';
import 'package:pet_pal/widgets/today_dashboard_section.dart';

import '../helpers/pump_app.dart';

class _FakePetRepository implements PetRepository {
  _FakePetRepository(this.pets);

  final List<Pet> pets;

  @override
  Future<List<Pet>> getPets() async => List.of(pets);

  @override
  Future<void> insertPet(Pet pet) async => pets.add(pet);

  @override
  Future<void> updatePet(Pet pet) async {
    final index = pets.indexWhere((p) => p.id == pet.id);
    if (index != -1) pets[index] = pet;
  }

  @override
  Future<void> deletePet(String id) async {
    pets.removeWhere((p) => p.id == id);
  }
}

/// Un único pet fake: mantiene showPetName en false (como antes de que
/// TodayDashboardSection empezara a depender de petsProvider), así los
/// asserts de texto existentes no necesitan saber sobre encabezados de
/// mascota.
List<Override> _fakePetsOverride() => [
      petRepositoryProvider.overrideWithValue(_FakePetRepository([_pet()])),
    ];

DashboardEvent _event({
  required String title,
  required DateTime date,
  String petId = 'pet-1',
  String petName = 'Firulais',
  String type = 'appointment',
}) {
  return DashboardEvent(
    petId: petId,
    petName: petName,
    date: date,
    title: title,
    type: type,
  );
}

Pet _pet() => Pet(
      name: 'Firulais',
      species: 'Perro',
      breed: 'Mestizo',
      dob: DateTime(2020, 1, 1),
      color: 'Marrón',
    );

/// Replica la transformación de título que DashboardEventTile aplica a los
/// eventos de tipo 'appointment' (el default de _event()) cuando
/// showPetName es false -mismo caso de estos tests, un único pet fake-:
/// le quita el prefijo "Cita: " si ya lo trae y le agrega la fecha.
/// Ver lib/widgets/today_dashboard_section.dart, DashboardEventTile.build.
String _appointmentDisplayTitle(String title, DateTime date) {
  final pureTitle = title.startsWith('Cita: ') ? title.substring(6) : title;
  return 'Cita: $pureTitle - ${DateFormat('dd/MM/yyyy').format(date)}';
}

void main() {
  testWidgets('muestra un indicador de carga mientras el provider resuelve', (tester) async {
    await pumpApp(
      tester,
      const TodayDashboardSection(),
      overrides: [
        todayDashboardProvider.overrideWith((ref) => Completer<List<DashboardEvent>>().future),
        ..._fakePetsOverride(),
      ],
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('no muestra nada si no hay eventos accionables', (tester) async {
    await pumpApp(
      tester,
      const TodayDashboardSection(),
      overrides: [
        todayDashboardProvider.overrideWith((ref) async => <DashboardEvent>[]),
        ..._fakePetsOverride(),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Hoy'), findsNothing);
  });

  testWidgets('muestra el título "Hoy" y los eventos cuando hay datos', (tester) async {
    final vencidoDate = DateTime.now().subtract(const Duration(days: 2));
    final futuroDate = DateTime.now().add(const Duration(days: 10));

    await pumpApp(
      tester,
      const TodayDashboardSection(),
      overrides: [
        todayDashboardProvider.overrideWith((ref) async => [
              _event(title: 'Cita: Control vencido', date: vencidoDate),
              _event(title: 'Cita: Control futuro', date: futuroDate),
            ]),
        ..._fakePetsOverride(),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text(_appointmentDisplayTitle('Cita: Control vencido', vencidoDate)), findsOneWidget);
    expect(find.text(_appointmentDisplayTitle('Cita: Control futuro', futuroDate)), findsOneWidget);
  });

  testWidgets('el evento vencido se renderiza antes que el futuro', (tester) async {
    final vencidoDate = DateTime.now().subtract(const Duration(days: 2));
    final futuroDate = DateTime.now().add(const Duration(days: 10));

    await pumpApp(
      tester,
      const TodayDashboardSection(),
      overrides: [
        todayDashboardProvider.overrideWith((ref) async => [
              _event(title: 'Vencido', date: vencidoDate),
              _event(title: 'Futuro', date: futuroDate),
            ]),
        ..._fakePetsOverride(),
      ],
    );
    await tester.pumpAndSettle();

    final vencidoOffset = tester.getTopLeft(find.text(_appointmentDisplayTitle('Vencido', vencidoDate))).dy;
    final futuroOffset = tester.getTopLeft(find.text(_appointmentDisplayTitle('Futuro', futuroDate))).dy;
    expect(vencidoOffset, lessThan(futuroOffset));
  });

  testWidgets('muestra un mensaje de error si el provider falla', (tester) async {
    await pumpApp(
      tester,
      const TodayDashboardSection(),
      overrides: [
        todayDashboardProvider.overrideWith((ref) async => throw Exception('fallo de red')),
        ..._fakePetsOverride(),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No se pudo cargar el resumen de hoy'), findsOneWidget);
  });

  testWidgets('"y N más..." navega a TodayEventsScreen con el resto de los eventos', (tester) async {
    final events = List.generate(
      7,
      (i) => _event(title: 'Evento $i', date: DateTime.now().add(Duration(days: i))),
    );

    await pumpApp(
      tester,
      const TodayDashboardSection(),
      overrides: [
        todayDashboardProvider.overrideWith((ref) async => events),
        ..._fakePetsOverride(),
      ],
    );
    await tester.pumpAndSettle();

    // El texto del botón cambió de "y N más..." a "Ver todo (N más)" en
    // c3d050b, sin actualizar este test en su momento.
    expect(find.text('Ver todo (2 más)'), findsOneWidget);
    // El sexto y séptimo evento están recortados en la sección resumida.
    expect(find.text('Evento 5'), findsNothing);
    expect(find.text('Evento 6'), findsNothing);

    await tester.tap(find.text('Ver todo (2 más)'));
    await tester.pumpAndSettle();

    expect(find.text('Eventos de hoy'), findsOneWidget);
    for (final event in events) {
      expect(find.text(_appointmentDisplayTitle(event.title, event.date)), findsOneWidget);
    }
  });

  testWidgets('el fondo de un evento vencido se adapta al tema (no usa Colors.red[50] fijo)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
          home: Scaffold(
            body: DashboardEventTile(
              event: _event(title: 'Vencido', date: DateTime.now().subtract(const Duration(days: 2))),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = tester.widget<Card>(find.byType(Card));
    final context = tester.element(find.byType(Card));
    final expectedColor = Theme.of(context).colorScheme.errorContainer;

    expect(card.color, expectedColor);
    expect(card.color, isNot(Colors.red[50]));
  });

  group('screenForDashboardEventType', () {
    test('mapea cada tipo accionable a la pantalla de la mascota correspondiente', () {
      final pet = _pet();

      expect(screenForDashboardEventType('appointment', pet), isA<AppointmentsScreen>());
      expect(screenForDashboardEventType('next_vaccination', pet), isA<VaccinationsScreen>());
      expect(screenForDashboardEventType('next_deworming', pet), isA<DewormingScreen>());
      expect(screenForDashboardEventType('medication_end', pet), isA<MedicationsScreen>());
      expect(screenForDashboardEventType('tipo_desconocido', pet), isNull);
    });
  });

  // La resolución async de la mascota en DashboardEventTile._onTap
  // (ref.read(databaseHelperProvider).getPetById) usa sqflite_common_ffi,
  // que se comunica con un isolate en segundo plano. Eso es incompatible
  // con AutomatedTestWidgetsFlutterBinding (el binding de testWidgets):
  // el mensaje de respuesta del isolate nunca llega dentro de su zona
  // FakeAsync, ni siquiera envuelto en tester.runAsync, y el test cuelga
  // hasta el timeout de 10 minutos. Por eso ningún test de este archivo
  // (ni de ningún otro widget test del repo) mezcla DB real con
  // testWidgets. Esa integración (tap → resolver mascota → navegar) se
  // verificó corriendo la app real en vez de con un test automatizado.
}
