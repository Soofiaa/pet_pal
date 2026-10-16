import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/screens/pet_detail_screen/pet_detail_screen.dart';

import '../helpers/pump_app.dart';

Pet _pet() => Pet(
      name: 'Luna',
      species: 'Perro',
      breed: 'Labrador',
      dob: DateTime(2020, 1, 1),
      color: 'Negro',
    );

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await pumpApp(tester, PetDetailScreen(pet: _pet()));
  await tester.pump();
}

void main() {
  testWidgets('la cabecera muestra especie, raza, color y edad', (tester) async {
    await _pump(tester);

    expect(find.textContaining('Perro'), findsWidgets);
    expect(find.textContaining('Labrador'), findsWidgets);
    expect(find.textContaining('Negro'), findsWidgets);
    expect(find.textContaining('año'), findsWidgets);
  });

  testWidgets('el AppBar tiene solo dos acciones, ambas con tooltip', (tester) async {
    await _pump(tester);

    expect(find.byTooltip('Editar mascota'), findsOneWidget);
    expect(find.byTooltip('Más opciones'), findsOneWidget);
    expect(find.byIcon(Icons.picture_as_pdf), findsNothing);
  });

  testWidgets('el menú agrupa la ficha PDF, los CSV y eliminar con etiquetas claras', (tester) async {
    await _pump(tester);

    await tester.tap(find.byTooltip('Más opciones'));
    await tester.pumpAndSettle();

    expect(find.text('Eliminar mascota'), findsOneWidget);
    expect(find.text('Ficha clínica (PDF)'), findsOneWidget);
    expect(find.text('Exportar historial (CSV)'), findsOneWidget);
    expect(find.text('Historial de peso'), findsOneWidget);
    expect(find.text('Historial de vacunas'), findsOneWidget);
    expect(find.text('Historial de medicación'), findsOneWidget);
    expect(find.text('Historial de desparasitación'), findsOneWidget);
  });
}
