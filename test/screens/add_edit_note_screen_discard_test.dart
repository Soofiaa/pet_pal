// La confirmación al salir de una nota debe ser la misma del resto de los
// formularios (UnsavedChangesGuard): mismo texto y mismo comportamiento.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/screens/add_edit_note_screen/add_edit_note_screen.dart';

Future<void> _openNoteForm(WidgetTester tester) async {
  final pet = Pet(
    name: 'Luna',
    species: 'Perro',
    breed: 'Labrador',
    dob: DateTime(2020, 1, 1),
    color: 'Negro',
  );
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => AddEditNoteScreen(pet: pet)),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin cambios, volver atrás sale sin preguntar', (tester) async {
    await _openNoteForm(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(AddEditNoteScreen), findsNothing);
  });

  testWidgets('con cambios, pregunta con el texto compartido', (tester) async {
    await _openNoteForm(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Algo');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('¿Descartar cambios?'), findsOneWidget);
    expect(
      find.text('Tienes cambios sin guardar. Si sales ahora, se perderán.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.byType(AddEditNoteScreen), findsNothing);
  });
}
