import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _searchCountryPrefsKey = 'search_country_code';

/// Países ofrecidos en el selector de "País para buscar direcciones"
/// (nombre en español -> código ISO 3166-1 alpha-2, el formato que espera
/// el parámetro `countrycodes` de Nominatim). Lista acotada a
/// Latinoamérica + un par de países frecuentes -no las ~195 del mundo-,
/// suficiente para un proyecto personal con un único usuario real.
const Map<String, String> searchCountryOptions = {
  'Chile': 'cl',
  'Argentina': 'ar',
  'Perú': 'pe',
  'Bolivia': 'bo',
  'Colombia': 'co',
  'Ecuador': 'ec',
  'Uruguay': 'uy',
  'Paraguay': 'py',
  'Venezuela': 've',
  'México': 'mx',
  'Brasil': 'br',
  'España': 'es',
  'Estados Unidos': 'us',
};

/// País (código ISO) que sesga las búsquedas de dirección de
/// GeocodingService.searchAddresses -ver su doc: sin sesgo, Nominatim
/// puede devolver una coincidencia de otro país antes que la correcta, o
/// ninguna del país esperado, para una dirección poco específica-.
///
/// Elegido explícitamente por la persona usuaria (no por GPS ni por la
/// configuración regional del teléfono: se decidió así para no requerir
/// permisos de ubicación ni depender de que el idioma/región del teléfono
/// coincida con dónde vive), persistido en shared_preferences -mismo
/// patrón que ThemeModeNotifier: arranca en el default mientras se lee el
/// valor guardado, evitando bloquear el primer frame con el await-.
class SearchCountryNotifier extends Notifier<String> {
  static const String defaultCountryCode = 'cl';

  @override
  String build() {
    _loadSaved();
    return defaultCountryCode;
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_searchCountryPrefsKey);
    if (saved == null) return;
    state = saved;
  }

  Future<void> setCountryCode(String code) async {
    state = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_searchCountryPrefsKey, code);
  }
}

final searchCountryProvider =
    NotifierProvider<SearchCountryNotifier, String>(SearchCountryNotifier.new);
