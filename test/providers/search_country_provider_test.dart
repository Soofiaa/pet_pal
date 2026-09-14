// Pruebas de SearchCountryNotifier: mismo patrón que ThemeModeNotifier
// (arranca en un default sincrónico mientras se lee shared_preferences de
// forma asincrónica, y persiste cada cambio). SharedPreferences.setMockInitialValues
// es el mecanismo estándar del propio paquete shared_preferences para
// testear sin plataforma real.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pet_pal/providers/search_country_provider.dart';

void main() {
  group('SearchCountryNotifier', () {
    test('arranca en el default (Chile) cuando no hay nada guardado', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(searchCountryProvider), 'cl');
    });

    test('carga el valor guardado en shared_preferences al iniciar', () async {
      SharedPreferences.setMockInitialValues({'search_country_code': 'ar'});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // El primer read dispara build() (Riverpod es lazy: _loadSaved recién
      // arranca acá, no antes) y ve el default mientras esa carga async no
      // resolvió. pumpEventQueue (no Future.delayed(Duration.zero)) porque
      // SharedPreferences.getInstance() encadena varias vueltas de Future.
      expect(container.read(searchCountryProvider), 'cl');
      await pumpEventQueue();

      expect(container.read(searchCountryProvider), 'ar');
    });

    test('setCountryCode actualiza el estado y persiste en shared_preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(searchCountryProvider.notifier).setCountryCode('pe');

      expect(container.read(searchCountryProvider), 'pe');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('search_country_code'), 'pe');
    });

    test(
      'un cambio persiste entre "reinicios" (nuevo ProviderContainer, misma '
      'shared_preferences)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final firstContainer = ProviderContainer();
        await firstContainer
            .read(searchCountryProvider.notifier)
            .setCountryCode('mx');
        firstContainer.dispose();

        final secondContainer = ProviderContainer();
        addTearDown(secondContainer.dispose);
        // Mismo motivo que el test anterior: el primer read dispara build()
        // recién acá, así que hay que leer antes de pumpear para que
        // _loadSaved() tenga algo que resolver.
        secondContainer.read(searchCountryProvider);
        await pumpEventQueue();

        expect(secondContainer.read(searchCountryProvider), 'mx');
      },
    );
  });

  test('searchCountryOptions incluye Chile como opción con código "cl"', () {
    expect(searchCountryOptions['Chile'], 'cl');
  });
}
