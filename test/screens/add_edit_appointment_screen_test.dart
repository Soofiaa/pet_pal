// Tests de widget del diálogo "Buscar Ubicación" en
// AddEditAppointmentScreen. Usan AddressSearcher inyectado (parámetro
// addressSearcher del widget, ver add_edit_appointment_screen.dart) en vez
// de un GeocodingService real, para no golpear la red de Nominatim en
// flutter test -el contrato de que GeocodingService nunca lanza y devuelve
// lista vacía en caso de error ya está probado en geocoding_service_test.dart-.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pet_pal/screens/add_edit_appointment_screen/add_edit_appointment_screen.dart';

import '../helpers/pump_app.dart';

void main() {
  group('AddEditAppointmentScreen - diálogo de búsqueda de ubicación', () {
    testWidgets(
      'seleccionar un resultado de la lista actualiza el campo Lugar de la pantalla principal',
      (tester) async {
        await pumpApp(
          tester,
          AddEditAppointmentScreen(
            petId: 'pet-1',
            addressSearcher: (query) async => [
              'Av. Siempre Viva 123, Springfield',
              'Av. Siempre Viva 742, Springfield',
            ],
          ),
        );

        await tester.tap(find.byTooltip('Buscar en el mapa'));
        await tester.pumpAndSettle();
        expect(find.text('Buscar Ubicación'), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextField, 'Introduce un lugar o dirección'),
          'Siempre Viva',
        );
        // Deja pasar el debounce (500ms) más el tiempo de resolución del
        // fake, y asienta el frame con los resultados ya pintados.
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        expect(find.text('Av. Siempre Viva 123, Springfield'), findsOneWidget);
        expect(find.text('Av. Siempre Viva 742, Springfield'), findsOneWidget);

        await tester.tap(find.text('Av. Siempre Viva 123, Springfield'));
        await tester.pumpAndSettle();

        expect(find.text('Buscar Ubicación'), findsNothing,
            reason: 'seleccionar un resultado debe cerrar el diálogo');
        expect(
          find.text('Av. Siempre Viva 123, Springfield'),
          findsOneWidget,
          reason: 'el campo Lugar de la pantalla principal debe quedar con la '
              'dirección elegida',
        );
        expect(find.text('Ubicación actualizada con el lugar buscado.'), findsOneWidget);
      },
    );

    testWidgets(
      'sin resultados de búsqueda (ej. sin conexión), el diálogo muestra '
      '"Sin sugerencias" y el usuario puede cancelar y seguir escribiendo la '
      'ubicación a mano sin que nada se lo impida',
      (tester) async {
        await pumpApp(
          tester,
          AddEditAppointmentScreen(
            petId: 'pet-1',
            // GeocodingService ya garantiza (ver geocoding_service_test.dart)
            // que sin conexión, timeout o error del servidor devuelve lista
            // vacía en vez de lanzar; acá se simula ese mismo contrato.
            addressSearcher: (query) async => [],
          ),
        );

        await tester.tap(find.byTooltip('Buscar en el mapa'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Introduce un lugar o dirección'),
          'Cualquier dirección',
        );
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        expect(find.text('Sin sugerencias'), findsOneWidget);

        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();

        expect(find.text('Buscar Ubicación'), findsNothing);

        // El usuario sigue pudiendo completar el campo Lugar a mano, sin
        // que la búsqueda fallida bloquee nada.
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Lugar (Opcional)'),
          'Calle Falsa 123 (tipeada a mano)',
        );
        await tester.pump();

        expect(find.text('Calle Falsa 123 (tipeada a mano)'), findsOneWidget);
      },
    );
  });
}
