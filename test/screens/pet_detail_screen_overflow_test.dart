// La grilla de funciones del detalle tenía alto fijo (celdas cuadradas) y
// desbordaba ("BOTTOM OVERFLOWED") con la fuente del sistema al 150%.
// El getPetById de initState queda sin resolver (sin sqflite en el test),
// lo que no afecta el primer render con la mascota recibida.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/screens/pet_detail_screen/pet_detail_screen.dart';

import '../helpers/pump_app.dart';

void main() {
  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('no desborda con fuente x$scale', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);

      final pet = Pet(
        name: 'Luna',
        species: 'Perro',
        breed: 'Labrador',
        dob: DateTime(2020, 1, 1),
        color: 'Negro',
      );

      await pumpApp(
        tester,
        MediaQuery(
          data: MediaQueryData(
            size: const Size(412, 914),
            textScaler: TextScaler.linear(scale),
          ),
          child: PetDetailScreen(pet: pet),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  }
}
