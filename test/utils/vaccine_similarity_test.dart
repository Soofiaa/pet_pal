// Criterio de similitud entre vacunas al cargar una nueva (ver
// VaccineSimilarity). Cubre el caso que hacía perder la dosis de otra vacuna:
// una palabra clave de vacuna múltiple en UN solo de los nombres.
import 'package:flutter_test/flutter_test.dart';

import 'package:pet_pal/utils/vaccine_similarity.dart';

void main() {
  group('VaccineSimilarity.isSimilar', () {
    test('mismo nombre, sin distinguir mayúsculas ni espacios, es similar', () {
      expect(VaccineSimilarity.isSimilar('Rabia', 'rabia'), isTrue);
      expect(VaccineSimilarity.isSimilar('  Rabia  ', 'Rabia'), isTrue);
    });

    test('una vacuna simple NO es similar a una múltiple (caso del bug)', () {
      expect(VaccineSimilarity.isSimilar('Sextuple', 'Rabia'), isFalse);
      expect(VaccineSimilarity.isSimilar('Rabia', 'Sextuple'), isFalse);
      expect(VaccineSimilarity.isSimilar('Triple felina', 'Rabia'), isFalse);
    });

    test('dos vacunas que comparten una palabra clave son similares', () {
      expect(VaccineSimilarity.isSimilar('Triple felina', 'Triple canina'), isTrue);
      expect(VaccineSimilarity.isSimilar('Sextuple cachorro', 'Sextuple'), isTrue);
    });

    test('palabras clave distintas no son similares', () {
      expect(VaccineSimilarity.isSimilar('Triple felina', 'Sextuple'), isFalse);
    });

    test('nombres vacíos nunca son similares', () {
      expect(VaccineSimilarity.isSimilar('', 'Rabia'), isFalse);
      expect(VaccineSimilarity.isSimilar('Rabia', '   '), isFalse);
    });
  });
}
