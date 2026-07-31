import 'package:flutter_test/flutter_test.dart';
import 'package:pet_pal/models/food_allergy.dart';

void main() {
  group('FoodAllergy.getEventsFromList', () {
    test('mapea cada alergia a un evento de tipo food_allergy', () {
      final dateRecorded = DateTime(2026, 3, 10);
      final allergies = [
        FoodAllergy(
          id: 1,
          petId: 'pet-1',
          food: 'Pollo',
          dateRecorded: dateRecorded,
        ),
      ];

      final events = FoodAllergy.getEventsFromList(allergies);

      expect(events, hasLength(1));
      expect(events.first['id'], 1);
      expect(events.first['petId'], 'pet-1');
      expect(events.first['date'], dateRecorded);
      expect(events.first['title'], 'Alergia registrada: Pollo');
      expect(events.first['type'], 'food_allergy');
    });

    test('devuelve una lista vacía si no hay alergias', () {
      expect(FoodAllergy.getEventsFromList([]), isEmpty);
    });

    test('mapea múltiples alergias en el mismo orden de entrada', () {
      final allergies = [
        FoodAllergy(
          id: 1,
          petId: 'pet-1',
          food: 'Pollo',
          dateRecorded: DateTime(2026, 1, 1),
        ),
        FoodAllergy(
          id: 2,
          petId: 'pet-1',
          food: 'Trigo',
          dateRecorded: DateTime(2026, 2, 1),
        ),
      ];

      final events = FoodAllergy.getEventsFromList(allergies);

      expect(events, hasLength(2));
      expect(events[0]['title'], 'Alergia registrada: Pollo');
      expect(events[1]['title'], 'Alergia registrada: Trigo');
    });
  });
}
