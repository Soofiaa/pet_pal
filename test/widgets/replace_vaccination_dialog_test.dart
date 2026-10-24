// Diálogo para elegir qué vacuna reemplaza a la nueva. Se prueba cada salida:
// elegir una opción, "son independientes" y cerrar sin elegir.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pet_pal/models/vaccination.dart';
import 'package:pet_pal/widgets/replace_vaccination_dialog.dart';

import '../helpers/pump_app.dart';

Vaccination _vax(String name, DateTime date) =>
    Vaccination(petId: 'pet-1', vaccineName: name, date: date);

/// Abre el diálogo con [similar] y devuelve el resultado que entrega.
Future<Vaccination?> _open(
  WidgetTester tester,
  List<Vaccination> similar,
  Future<void> Function() interact,
) async {
  Vaccination? result;
  await pumpApp(
    tester,
    Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          result = await showReplaceVaccinationDialog(context, similar);
        },
        child: const Text('abrir'),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  await interact();
  await tester.pumpAndSettle();
  return result;
}

void main() {
  final rabia = _vax('Rabia', DateTime(2025, 3, 1));
  final sextuple = _vax('Sextuple', DateTime(2025, 6, 1));

  testWidgets('lista cada vacuna similar con su fecha', (tester) async {
    await _open(tester, [sextuple, rabia], () async {
      expect(find.text('Sextuple · 01/06/2025'), findsOneWidget);
      expect(find.text('Rabia · 01/03/2025'), findsOneWidget);
      expect(find.text('No, son independientes'), findsOneWidget);
    });
  });

  testWidgets('elegir una vacuna devuelve esa vacuna', (tester) async {
    final result = await _open(tester, [sextuple, rabia], () async {
      await tester.tap(find.text('Rabia · 01/03/2025'));
    });
    expect(result, same(rabia));
  });

  testWidgets('"son independientes" no reemplaza nada', (tester) async {
    final result = await _open(tester, [sextuple, rabia], () async {
      await tester.tap(find.text('No, son independientes'));
    });
    expect(result, isNull);
  });

  testWidgets('cerrar el diálogo sin elegir no reemplaza nada', (tester) async {
    final result = await _open(tester, [sextuple, rabia], () async {
      // Toca fuera del diálogo para cerrarlo.
      await tester.tapAt(const Offset(5, 5));
    });
    expect(result, isNull);
  });
}
