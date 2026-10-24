import 'package:flutter_test/flutter_test.dart';
import 'package:pet_pal/screens/vaccinations_screen/vaccinations_screen.dart';

void main() {
  final now = DateTime(2026, 10, 16, 15, 30);

  test('una próxima dosis anterior a hoy está vencida', () {
    expect(isNextDoseOverdue(DateTime(2026, 10, 15), now: now), isTrue);
  });

  test('una próxima dosis de hoy o futura sigue vigente', () {
    expect(isNextDoseOverdue(DateTime(2026, 10, 16), now: now), isFalse);
    expect(isNextDoseOverdue(DateTime(2026, 11, 1), now: now), isFalse);
  });
}
