/// Criterio para decidir si una vacuna nueva podría reemplazar a una ya
/// registrada. Dos nombres son "similares" si:
///   - son el mismo nombre (sin distinguir mayúsculas ni espacios), o
///   - ambos contienen la misma palabra clave de vacuna múltiple
///     (ej. "Triple felina" y "Triple canina").
///
/// Antes la comparación era cruzada: bastaba que UNO de los dos nombres
/// tuviera la palabra clave. Así "Rabia" aparecía como similar a "Sextuple"
/// y, si el usuario decía que la nueva la reemplazaba, la dosis de Rabia
/// dejaba de mostrarse en el panel sin aviso.
class VaccineSimilarity {
  VaccineSimilarity._();

  static const List<String> multipleKeywords = [
    'sextuple',
    'octuple',
    'polivalente',
    'multiple',
    'triple',
    'cuádruple',
  ];

  static String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  static Set<String> _keywordsIn(String normalized) => {
        for (final keyword in multipleKeywords)
          if (normalized.contains(keyword)) keyword,
      };

  static bool isSimilar(String newName, String existingName) {
    final a = _normalize(newName);
    final b = _normalize(existingName);
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;
    return _keywordsIn(a).intersection(_keywordsIn(b)).isNotEmpty;
  }
}
