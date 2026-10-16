// Con fuente grande, "Desparasitaciones" se partía a mitad de palabra
// ("Desparasitacio / nes") porque la etiqueta solo acotaba el factor de
// escala a un máximo fijo, sin considerar el ancho real de la tarjeta.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/screens/pet_detail_screen/pet_detail_screen.dart';

import '../helpers/pump_app.dart';

void main() {
  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('las etiquetas no se parten a mitad de palabra con fuente x$scale', (tester) async {
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

      final paragraph = tester.renderObject<RenderParagraph>(find.text('Desparasitaciones'));
      final boxes = paragraph.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 'Desparasitaciones'.length),
      );
      final lineTops = boxes.map((b) => b.top).toSet();
      expect(lineTops.length, 1, reason: 'una sola línea: no se partió la palabra');
    });
  }
}
