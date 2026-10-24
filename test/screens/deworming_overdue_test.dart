import 'package:flutter_test/flutter_test.dart';
import 'package:pet_pal/models/deworming.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/providers/deworming_providers.dart';
import 'package:pet_pal/screens/deworming_screen/deworming_screen.dart';

import '../helpers/pump_app.dart';

class _FakeDewormingsNotifier extends DewormingsNotifier {
  final List<Deworming> items;
  _FakeDewormingsNotifier(this.items);

  @override
  Future<List<Deworming>> build(String arg) async => items;
}

Pet _pet() => Pet(
      id: 'pet-1',
      name: 'Luna',
      species: 'Perro',
      breed: 'Mestizo',
      dob: DateTime(2020, 1, 1),
      color: 'Café',
    );

Future<void> _pump(WidgetTester tester, Deworming d) async {
  await pumpApp(
    tester,
    DewormingScreen(pet: _pet()),
    overrides: [
      dewormingsProvider.overrideWith(() => _FakeDewormingsNotifier([d])),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('una próxima fecha ya pasada se muestra como vencida', (tester) async {
    final past = DateTime.now().subtract(const Duration(days: 10));
    await _pump(
      tester,
      Deworming(
        id: 'd1',
        petId: 'pet-1',
        product: 'Drontal',
        date: DateTime.now().subtract(const Duration(days: 100)),
        nextDate: past,
        type: 'interna',
      ),
    );

    expect(find.textContaining('Vencida desde:'), findsOneWidget);
    expect(find.textContaining('Próxima fecha:'), findsNothing);
  });

  testWidgets('una próxima fecha futura sigue como próxima', (tester) async {
    final future = DateTime.now().add(const Duration(days: 20));
    await _pump(
      tester,
      Deworming(
        id: 'd1',
        petId: 'pet-1',
        product: 'Drontal',
        date: DateTime.now().subtract(const Duration(days: 10)),
        nextDate: future,
        type: 'interna',
      ),
    );

    expect(find.textContaining('Próxima fecha:'), findsOneWidget);
    expect(find.textContaining('Vencida desde:'), findsNothing);
  });
}
