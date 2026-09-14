// Pruebas de GeocodingService: la propiedad real a proteger es que un fallo
// de red/parseo NUNCA se propaga como excepción -searchAddresses es una
// ayuda opcional para completar el campo de ubicación de una cita, nunca un
// requisito para guardarla-, así que siempre debe resolver a una lista
// (vacía en el caso de error), nunca lanzar. Se usa http.testing.MockClient
// (parte del propio paquete http, sin agregar mockito) para no golpear la
// red real de Nominatim en flutter test.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:pet_pal/services/geocoding_service.dart';

void main() {
  group('GeocodingService.searchAddresses', () {
    test('respuesta exitosa con resultados devuelve los display_name en orden', () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'nominatim.openstreetmap.org');
        expect(request.url.queryParameters['q'], 'Av. Siempre Viva');
        expect(request.url.queryParameters['format'], 'json');
        expect(request.headers['User-Agent'], isNotEmpty);

        return http.Response(
          '''
          [
            {"display_name": "Av. Siempre Viva 123, Springfield"},
            {"display_name": "Av. Siempre Viva 742, Springfield"}
          ]
          ''',
          200,
        );
      });

      final service = GeocodingService(client: client);
      final results = await service.searchAddresses('Av. Siempre Viva');

      expect(results, [
        'Av. Siempre Viva 123, Springfield',
        'Av. Siempre Viva 742, Springfield',
      ]);
    });

    test('respuesta exitosa sin resultados (lista vacía) devuelve lista vacía', () async {
      final client = MockClient((request) async => http.Response('[]', 200));

      final service = GeocodingService(client: client);
      final results = await service.searchAddresses('direccion-que-no-existe-xyz');

      expect(results, isEmpty);
    });

    test('una consulta en blanco no llega a hacer la request', () async {
      bool requestMade = false;
      final client = MockClient((request) async {
        requestMade = true;
        return http.Response('[]', 200);
      });

      final service = GeocodingService(client: client);
      final results = await service.searchAddresses('   ');

      expect(results, isEmpty);
      expect(requestMade, isFalse);
    });

    test(
      'timeout de red no lanza excepción: devuelve lista vacía',
      () async {
        final client = MockClient((request) async {
          // Simula una respuesta que nunca llega dentro del timeout del
          // service (5s): el propio test usa un delay mayor para forzar el
          // timeout sin depender de temporizadores reales de 5 segundos.
          throw TimeoutException('Se agotó el tiempo de espera');
        });

        final service = GeocodingService(client: client);

        await expectLater(
          service.searchAddresses('Av. Siempre Viva'),
          completion(isEmpty),
          reason: 'un timeout de red debe resolver a lista vacía, no propagar la excepción',
        );
      },
    );

    test('sin conexión (SocketException-like) no lanza excepción: devuelve lista vacía', () async {
      final client = MockClient((request) async {
        throw const HttpException('Failed host lookup');
      });

      final service = GeocodingService(client: client);

      await expectLater(
        service.searchAddresses('Av. Siempre Viva'),
        completion(isEmpty),
      );
    });

    test('respuesta 429 (rate limit excedido) no lanza excepción: devuelve lista vacía', () async {
      final client = MockClient((request) async => http.Response('Usage limit reached', 429));

      final service = GeocodingService(client: client);
      final results = await service.searchAddresses('Av. Siempre Viva');

      expect(results, isEmpty);
    });

    test('un cuerpo con forma inesperada (no es una lista) no lanza excepción', () async {
      final client = MockClient((request) async => http.Response('{"error": "algo raro"}', 200));

      final service = GeocodingService(client: client);
      final results = await service.searchAddresses('Av. Siempre Viva');

      expect(results, isEmpty);
    });

    test('items sin display_name se descartan sin romper el resto de la lista', () async {
      final client = MockClient((request) async => http.Response(
            '''
            [
              {"lat": "1.0", "lon": "2.0"},
              {"display_name": "Dirección válida"}
            ]
            ''',
            200,
          ));

      final service = GeocodingService(client: client);
      final results = await service.searchAddresses('Av. Siempre Viva');

      expect(results, ['Dirección válida']);
    });
  });

  group('GeocodingService.searchAddresses - sesgo por país (countryCode)', () {
    // Reproduce con evidencia el diagnóstico real: sin countrycodes,
    // Nominatim busca en todo el planeta y puede devolver una coincidencia
    // de otro país antes que la correcta (o ninguna del país esperado) para
    // una dirección poco específica. Acá solo se prueba que el parámetro se
    // arma o se omite correctamente -el comportamiento de Nominatim en sí ya
    // se verificó a mano contra la API real-.
    test('countryCode agrega countrycodes a la URL', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response('[]', 200);
      });

      final service = GeocodingService(client: client);
      await service.searchAddresses('Av Valparaiso 1362', countryCode: 'cl');

      expect(capturedUri?.queryParameters['countrycodes'], 'cl');
    });

    test('sin countryCode no se agrega countrycodes a la URL', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response('[]', 200);
      });

      final service = GeocodingService(client: client);
      await service.searchAddresses('Av Valparaiso 1362');

      expect(capturedUri?.queryParameters.containsKey('countrycodes'), isFalse);
    });

    test('countryCode vacío se trata igual que no pasarlo', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response('[]', 200);
      });

      final service = GeocodingService(client: client);
      await service.searchAddresses('Av Valparaiso 1362', countryCode: '');

      expect(capturedUri?.queryParameters.containsKey('countrycodes'), isFalse);
    });
  });
}
