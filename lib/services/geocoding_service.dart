// geocoding_service.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Envuelve la búsqueda de direcciones contra la API pública de Nominatim
/// (OpenStreetMap) -mismo espíritu que NotificationService: una capa
/// delgada sobre un servicio externo, sin persistir nada ni orquestar el
/// resto de la app-. No requiere API key, pero exige un User-Agent
/// identificable (política de uso de Nominatim) y un máximo de 1 request
/// por segundo; ese rate limit lo respeta quien llama a este service (ver
/// el debounce en el diálogo de búsqueda de add_edit_appointment_screen.dart),
/// no este método en sí.
class GeocodingService {
  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _baseUrl = 'https://nominatim.openstreetmap.org/search';
  static const String _userAgent = 'PetPal/1.0 (https://github.com/Soofiaa/pet_pal)';
  static const Duration _timeout = Duration(seconds: 5);

  /// Devuelve las direcciones (`display_name`) que coinciden con [query].
  ///
  /// [countryCode] sesga la búsqueda a un país (código ISO 3166-1 alpha-2,
  /// ej. "cl"), vía el parámetro `countrycodes` de Nominatim. Sin esto,
  /// Nominatim busca en todo el planeta y ordena por "importancia" del
  /// lugar en OSM: para una dirección poco específica (ej. sin ciudad) eso
  /// puede devolver una coincidencia de otro país antes que la correcta, o
  /// directamente ninguna del país esperado -diagnosticado con casos reales
  /// contra la API: "Av Valparaiso 1362" sin sesgo devolvía una dirección
  /// en Brasil-. Quién sesga (o no) es decisión de quien llama; este
  /// service no asume ningún país por defecto.
  ///
  /// Nunca lanza: sin conexión, timeout, una respuesta que no sea 200 (por
  /// ejemplo 429 por haber excedido el rate limit) o un cuerpo con forma
  /// inesperada devuelven lista vacía en vez de propagar la excepción. La
  /// búsqueda es una ayuda para completar el campo de ubicación, nunca un
  /// requisito para guardar la cita, así que un fallo acá no debe
  /// interrumpir al usuario.
  Future<List<String>> searchAddresses(String query, {String? countryCode}) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final Uri uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'q': trimmed,
      'format': 'json',
      'addressdetails': '1',
      'limit': '5',
      if (countryCode != null && countryCode.isNotEmpty) 'countrycodes': countryCode,
    });

    try {
      final http.Response response = await _client
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(_timeout);

      // Caso inesperado (no "sin resultados", que es 200 con lista vacía):
      // la propia API rechazó o falló la request. Se registra para poder
      // diagnosticar -ver sesión de diagnóstico previa, donde esto habría
      // distinguido un 429 real de "Nominatim no tiene esa dirección"-.
      if (response.statusCode != 200) {
        debugPrint(
            'GeocodingService: Nominatim respondió ${response.statusCode} '
            'al buscar "$trimmed" (uri: $uri) - body: ${response.body}');
        return [];
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! List) {
        // Caso inesperado: 200 pero con una forma de cuerpo que este
        // parseo no anticipa.
        debugPrint(
            'GeocodingService: el body de Nominatim no es una lista JSON '
            '(runtimeType: ${decoded.runtimeType}) para "$trimmed" (uri: '
            '$uri) - body: ${response.body}');
        return [];
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map((item) => item['display_name'])
          .whereType<String>()
          .toList();
    } catch (e) {
      // Cualquier falla de red (sin conexión, timeout, DNS), de parseo del
      // JSON o de forma inesperada de la respuesta cae acá: se registra
      // para debug pero se devuelve lista vacía, nunca se relanza.
      debugPrint(
          'GeocodingService: error al buscar direcciones en Nominatim '
          '(uri: $uri) - ${e.runtimeType}: $e');
      return [];
    }
  }
}
