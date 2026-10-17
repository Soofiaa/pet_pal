import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_pal/models/dashboard_event.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/providers/dashboard_providers.dart';
import 'package:pet_pal/providers/pets_providers.dart';
import 'package:pet_pal/screens/home_screen/home_screen.dart';
import 'package:pet_pal/widgets/pet_card.dart';

import '../helpers/pump_app.dart';

Pet _pet(String name) => Pet(
      name: name,
      species: 'Perro',
      breed: 'Mestizo',
      dob: DateTime(2020, 1, 1),
      color: 'Marrón',
    );

class _PetsNotifier extends PetsNotifier {
  _PetsNotifier(this._pets);

  final List<Pet> _pets;

  @override
  Future<List<Pet>> build() async => _pets;
}

Future<void> _pumpHome(WidgetTester tester, List<Pet> pets, {List<DashboardEvent> events = const []}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await pumpApp(
    tester,
    const HomeScreen(),
    overrides: [
      petsProvider.overrideWith(() => _PetsNotifier(pets)),
      todayDashboardProvider.overrideWith((ref) async => events),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('con varias mascotas las apila una debajo de otra a todo el ancho', (tester) async {
    await _pumpHome(tester, [_pet('Olivia'), _pet('Luna'), _pet('Max')]);

    expect(find.byType(PetCard), findsNWidgets(3));
    final olivia = tester.getTopLeft(find.widgetWithText(PetCard, 'Olivia'));
    final luna = tester.getTopLeft(find.widgetWithText(PetCard, 'Luna'));
    expect(luna.dx, olivia.dx);
    expect(luna.dy, greaterThan(olivia.dy));
    expect(tester.getSize(find.widgetWithText(PetCard, 'Olivia')).width, greaterThan(350));
  });
  testWidgets('cada tarjeta muestra los pendientes de su mascota', (tester) async {
    final olivia = _pet('Olivia');
    final luna = _pet('Luna');
    await _pumpHome(
      tester,
      [olivia, luna],
      events: [
        DashboardEvent(
          petId: olivia.id,
          petName: 'Olivia',
          date: DateTime.now().subtract(const Duration(days: 5)),
          title: 'Próxima vacunación',
          type: 'next_vaccination',
        ),
      ],
    );

    expect(find.byIcon(Icons.vaccines), findsOneWidget);
    expect(
      find.descendant(of: find.widgetWithText(PetCard, 'Olivia'), matching: find.byIcon(Icons.vaccines)),
      findsOneWidget,
    );
  });
}
