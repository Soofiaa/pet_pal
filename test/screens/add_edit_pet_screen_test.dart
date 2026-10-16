import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_pal/screens/add_edit_pet_screen/add_edit_pet_screen.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('los campos obligatorios se marcan con asterisco', (tester) async {
    await pumpApp(tester, const AddEditPetScreen());

    for (final label in ['Nombre *', 'Especie (ej. Perro, Gato) *', 'Raza *', 'Color *']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Fecha de nacimiento *'), findsOneWidget);
  });

  testWidgets('una mascota nueva no asume la fecha de hoy como nacimiento', (tester) async {
    await pumpApp(tester, const AddEditPetScreen());

    expect(find.text('Toca para elegir'), findsOneWidget);
  });

  testWidgets('salir del formulario con cambios sin guardar pide confirmación', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AddEditPetScreen()),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar cambios?'), findsNothing);

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Luna');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('¿Descartar cambios?'), findsOneWidget);
  });

  testWidgets('guardar sin elegir fecha de nacimiento muestra el error', (tester) async {
    await pumpApp(tester, const AddEditPetScreen());

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Luna');
    await tester.enterText(fields.at(1), 'Perro');
    await tester.enterText(fields.at(2), 'Mestizo');
    await tester.enterText(fields.at(3), 'Café');

    await tester.ensureVisible(find.text('Guardar Mascota'));
    await tester.tap(find.text('Guardar Mascota'));
    await tester.pumpAndSettle();

    expect(find.text('Por favor, elige la fecha de nacimiento'), findsOneWidget);
  });
}
