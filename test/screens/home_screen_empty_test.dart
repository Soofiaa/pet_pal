import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/providers/dashboard_providers.dart';
import 'package:pet_pal/providers/pets_providers.dart';
import 'package:pet_pal/screens/home_screen/home_screen.dart';
import 'package:pet_pal/widgets/empty_state.dart';

import '../helpers/pump_app.dart';

class _EmptyPetsNotifier extends PetsNotifier {
  @override
  Future<List<Pet>> build() async => <Pet>[];
}

void main() {
  testWidgets('sin mascotas, el Home muestra el EmptyState estándar con la pista del "+"', (tester) async {
    await pumpApp(
      tester,
      const HomeScreen(),
      overrides: [
        petsProvider.overrideWith(_EmptyPetsNotifier.new),
        todayDashboardProvider.overrideWith((ref) async => []),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Aún no tienes mascotas'), findsOneWidget);
    expect(find.textContaining('"+"'), findsOneWidget);
  });
}
