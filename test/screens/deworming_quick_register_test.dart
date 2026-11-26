import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:pet_pal/models/deworming.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/providers/deworming_providers.dart';
import 'package:pet_pal/screens/deworming_screen/deworming_screen.dart';

import '../helpers/pump_app.dart';

/// Notifier fake que captura los registros insertados vía addDeworming.
class _CaptureDewormingsNotifier extends DewormingsNotifier {
  final List<Deworming> items;
  List<Deworming> inserted = [];

  _CaptureDewormingsNotifier(this.items);

  @override
  Future<List<Deworming>> build(String arg) async => items;

  @override
  Future<void> addDeworming(Deworming deworming) async {
    inserted.add(deworming);
  }
}

Pet _pet() => Pet(
      id: 'pet-1',
      name: 'Luna',
      species: 'Perro',
      breed: 'Mestizo',
      dob: DateTime(2020, 1, 1),
      color: 'Café',
    );

/// Lista compartida entre el notifier fake y el test para inspeccionar lo
/// insertado (pumpApp crea su propio ProviderScope, no hay acceso directo al
/// contenedor desde el test).
final List<Deworming> insertedRecords = [];

Future<void> _pump(WidgetTester tester, List<Deworming> dewormings) async {
  insertedRecords.clear();
  await pumpApp(
    tester,
    DewormingScreen(pet: _pet()),
    overrides: [
      dewormingsProvider.overrideWith(() {
        final notifier = _CaptureDewormingsNotifier(dewormings);
        notifier.inserted = insertedRecords;
        return notifier;
      }),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('botón aparece solo en registro vigente vencido',
      (tester) async {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final overdue = Deworming(
      id: 'd-overdue',
      petId: 'pet-1',
      product: 'Drontal',
      date: today.subtract(const Duration(days: 40)),
      nextDate: today.subtract(const Duration(days: 5)),
      type: 'interna',
      frequencyMonths: 1,
      isRecurring: true,
    );
    final upToDate = Deworming(
      id: 'd-up-to-date',
      petId: 'pet-1',
      product: 'Simparica',
      date: today.subtract(const Duration(days: 10)),
      nextDate: today.add(const Duration(days: 20)),
      type: 'externa',
      frequencyMonths: 1,
      isRecurring: true,
    );

    await _pump(tester, [overdue, upToDate]);

    // El vencido sí muestra el botón.
    expect(find.byTooltip('Registrar aplicación'), findsOneWidget);
  });

  testWidgets('no muestra botón cuando no hay registros vencidos',
      (tester) async {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final upToDate = Deworming(
      id: 'd-up-to-date',
      petId: 'pet-1',
      product: 'Simparica',
      date: today.subtract(const Duration(days: 10)),
      nextDate: today.add(const Duration(days: 20)),
      type: 'externa',
      frequencyMonths: 1,
      isRecurring: true,
    );

    await _pump(tester, [upToDate]);

    expect(find.byTooltip('Registrar aplicación'), findsNothing);
  });

  testWidgets('no muestra botón en registro superado por uno posterior',
      (tester) async {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final older = Deworming(
      id: 'd-older',
      petId: 'pet-1',
      product: 'Viejo',
      date: today.subtract(const Duration(days: 60)),
      nextDate: today.subtract(const Duration(days: 5)),
      type: 'interna',
      frequencyMonths: 1,
      isRecurring: true,
    );
    final newer = Deworming(
      id: 'd-newer',
      petId: 'pet-1',
      product: 'Nuevo',
      date: today.subtract(const Duration(days: 30)),
      nextDate: today.add(const Duration(days: 25)),
      type: 'interna',
      frequencyMonths: 1,
      isRecurring: true,
    );

    await _pump(tester, [older, newer]);

    expect(find.byTooltip('Registrar aplicación'), findsNothing);
  });

  testWidgets('confirmar crea registro nuevo con fecha de hoy y nextDate',
      (tester) async {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final overdue = Deworming(
      id: 'd-overdue',
      petId: 'pet-1',
      product: 'Drontal',
      date: today.subtract(const Duration(days: 40)),
      nextDate: today.subtract(const Duration(days: 5)),
      type: 'interna',
      frequencyMonths: 2,
      reminderDaysAhead: 1,
      isRecurring: true,
    );

    await _pump(tester, [overdue]);

    // Abre el diálogo y confirma.
    await tester.tap(find.byTooltip('Registrar aplicación'));
    await tester.pumpAndSettle();
    expect(find.text('Registrar aplicación'), findsOneWidget);

    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(insertedRecords, hasLength(1));
    final created = insertedRecords.first;
    expect(created.id, isNot(overdue.id));
    expect(created.petId, 'pet-1');
    expect(created.product, 'Drontal');
    expect(created.type, 'interna');
    expect(created.frequencyMonths, 2);
    expect(created.reminderDaysAhead, 1);
    expect(created.isRecurring, isTrue);
    // date = hoy (sin hora)
    expect(created.date.year, today.year);
    expect(created.date.month, today.month);
    expect(created.date.day, today.day);
    // nextDate = hoy + 2 meses
    final expectedNext = Deworming.addMonths(today, 2);
    expect(created.nextDate, expectedNext);
  });

  testWidgets('confirmar en no recurrente crea registro con nextDate null',
      (tester) async {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final overdue = Deworming(
      id: 'd-overdue',
      petId: 'pet-1',
      product: 'Drontal',
      date: today.subtract(const Duration(days: 40)),
      nextDate: today.subtract(const Duration(days: 5)),
      type: null,
      frequencyMonths: null,
      reminderDaysAhead: 0,
      isRecurring: false,
    );

    await _pump(tester, [overdue]);

    await tester.tap(find.byTooltip('Registrar aplicación'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(insertedRecords, hasLength(1));
    expect(insertedRecords.first.nextDate, isNull);
    expect(insertedRecords.first.type, isNull);
  });

  testWidgets('cancelar el diálogo no crea ningún registro',
      (tester) async {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final overdue = Deworming(
      id: 'd-overdue',
      petId: 'pet-1',
      product: 'Drontal',
      date: today.subtract(const Duration(days: 40)),
      nextDate: today.subtract(const Duration(days: 5)),
      type: 'interna',
      frequencyMonths: 1,
      isRecurring: true,
    );

    await _pump(tester, [overdue]);

    await tester.tap(find.byTooltip('Registrar aplicación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(insertedRecords, isEmpty);
  });

  testWidgets('legado con type null muestra botón y conserva type null',
      (tester) async {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final legado = Deworming(
      id: 'd-legado',
      petId: 'pet-1',
      product: 'Producto legado',
      date: today.subtract(const Duration(days: 40)),
      nextDate: today.subtract(const Duration(days: 5)),
      type: null,
      frequencyMonths: null,
      reminderDaysAhead: 0,
      isRecurring: false,
    );

    await _pump(tester, [legado]);

    expect(find.byTooltip('Registrar aplicación'), findsOneWidget);

    await tester.tap(find.byTooltip('Registrar aplicación'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(insertedRecords, hasLength(1));
    expect(insertedRecords.first.type, isNull);
    expect(insertedRecords.first.nextDate, isNull);
  });

  testWidgets('elegir ayer como fecha produce date = ayer y nextDate desde ayer',
      (tester) async {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final yesterday = today.subtract(const Duration(days: 1));
    final overdue = Deworming(
      id: 'd-overdue',
      petId: 'pet-1',
      product: 'Drontal',
      date: today.subtract(const Duration(days: 40)),
      nextDate: today.subtract(const Duration(days: 5)),
      type: 'interna',
      frequencyMonths: 3,
      reminderDaysAhead: 0,
      isRecurring: true,
    );

    await _pump(tester, [overdue]);

    await tester.tap(find.byTooltip('Registrar aplicación'));
    await tester.pumpAndSettle();

    // Abre el selector de fechas y elige ayer.
    await tester.tap(find.byIcon(Icons.calendar_today));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${yesterday.day}'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(insertedRecords, hasLength(1));
    final created = insertedRecords.first;
    expect(created.date.year, yesterday.year);
    expect(created.date.month, yesterday.month);
    expect(created.date.day, yesterday.day);
    final expectedNext = Deworming.addMonths(yesterday, 3);
    expect(created.nextDate, expectedNext);
  });
}
