import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/providers/dashboard_providers.dart';
import 'package:pet_pal/providers/pets_providers.dart';
import 'package:pet_pal/screens/home_screen/home_screen.dart';

import '../helpers/pump_app.dart';

class _OnePetNotifier extends PetsNotifier {
  @override
  Future<List<Pet>> build() async => [
        Pet(
          name: 'Luna',
          species: 'Perro',
          breed: 'Labrador',
          dob: DateTime(2020, 1, 1),
          color: 'Negro',
        ),
      ];
}

Future<void> _pump(WidgetTester tester) async {
  await pumpApp(
    tester,
    const HomeScreen(),
    overrides: [
      petsProvider.overrideWith(_OnePetNotifier.new),
      todayDashboardProvider.overrideWith((ref) async => []),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('borrar una mascota no es posible deslizando ni manteniendo pulsado', (tester) async {
    await _pump(tester);

    expect(find.byType(Dismissible), findsNothing);

    await tester.longPress(find.text('Luna'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar Eliminación'), findsNothing);
  });

  testWidgets('el botón + tiene tooltip', (tester) async {
    await _pump(tester);

    expect(find.byTooltip('Añadir mascota'), findsOneWidget);
  });

  testWidgets('el menú lateral se ordena en secciones y separa notificaciones de respaldo', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await _pump(tester);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Catálogos'), findsOneWidget);
    expect(find.text('Ayuda'), findsOneWidget);
    expect(find.text('Notificaciones'), findsOneWidget);
    expect(find.text('Respaldo y restauración'), findsOneWidget);
    expect(find.text('Notificaciones y Respaldo'), findsNothing);
  });
}
