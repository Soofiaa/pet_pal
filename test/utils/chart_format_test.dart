import 'package:flutter_test/flutter_test.dart';
import 'package:pet_pal/utils/chart_format.dart';

void main() {
  group('formatAxisValue', () {
    test('usa enteros cuando el intervalo es de 1 o más', () {
      expect(formatAxisValue(26, 1), '26');
      expect(formatAxisValue(40, 5), '40');
    });

    test('usa un decimal con intervalos fraccionarios', () {
      expect(formatAxisValue(39.5, 0.5), '39.5');
      expect(formatAxisValue(40.0, 0.5), '40.0');
    });

    test('las marcas consecutivas nunca producen etiquetas repetidas', () {
      const interval = 0.5;
      final labels = [for (var i = 0; i < 6; i++) formatAxisValue(24 + i * interval, interval)];
      expect(labels.toSet().length, labels.length);
    });

    test('usa dos decimales con intervalos muy pequeños', () {
      expect(formatAxisValue(25.05, 0.05), '25.05');
    });
  });
}
