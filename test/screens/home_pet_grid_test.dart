import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

Future<void> _pumpHome(WidgetTester tester, List<Pet> pets) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await pumpApp(
    tester,
    const HomeScreen(),
    overrides: [
      petsProvider.overrideWith(() => _PetsNotifier(pets)),
      todayDashboardProvider.overrideWith((ref) async => []),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('con varias mascotas las muestra en dos columnas', (tester) async {
    await _pumpHome(tester, [_pet('Olivia'), _pet('Luna'), _pet('Max')]);

    expect(find.byType(PetCard), findsNWidgets(3));
    final olivia = tester.getTopLeft(find.widgetWithText(PetCard, 'Olivia'));
    final luna = tester.getTopLeft(find.widgetWithText(PetCard, 'Luna'));
    final max = tester.getTopLeft(find.widgetWithText(PetCard, 'Max'));
    expect(olivia.dy, luna.dy);
    expect(luna.dx, greaterThan(olivia.dx));
    expect(max.dy, greaterThan(olivia.dy));
  });

  testWidgets('con una sola mascota la tarjeta ocupa la mitad del ancho', (tester) async {
    await _pumpHome(tester, [_pet('Olivia')]);

    final size = tester.getSize(find.byType(PetCard));
    expect(size.width, lessThan(200));
  });
}
