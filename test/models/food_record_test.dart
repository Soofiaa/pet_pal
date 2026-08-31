import 'package:flutter_test/flutter_test.dart';
import 'package:pet_pal/models/food_record.dart';

void main() {
  group('FoodRecord.toJson/fromJson', () {
    test('startDate y endDate null se persisten y releen como null', () {
      final record = FoodRecord(
        id: 1,
        petId: 'pet-1',
        foodName: 'Croquetas',
        startDate: null,
        endDate: null,
        notes: 'No recuerda cuándo empezó',
      );

      final rebuilt = FoodRecord.fromJson(record.toJson());

      expect(rebuilt.startDate, isNull);
      expect(rebuilt.endDate, isNull);
      expect(rebuilt.isOngoing, isTrue);
      expect(rebuilt.foodName, 'Croquetas');
    });

    test('startDate y endDate presentes se persisten y releen igual', () {
      final record = FoodRecord(
        id: 1,
        petId: 'pet-1',
        foodName: 'Croquetas',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 3, 1),
      );

      final rebuilt = FoodRecord.fromJson(record.toJson());

      expect(rebuilt.startDate, DateTime(2026, 1, 1));
      expect(rebuilt.endDate, DateTime(2026, 3, 1));
      expect(rebuilt.isOngoing, isFalse);
    });

    test(
      'isOngoing=false con endDate null (dejó de comerlo, fecha desconocida) '
      'se persiste y relee igual -antes indistinguible de "sigue comiendo"-',
      () {
        final record = FoodRecord(
          id: 1,
          petId: 'pet-1',
          foodName: 'Croquetas',
          endDate: null,
          isOngoing: false,
        );

        final rebuilt = FoodRecord.fromJson(record.toJson());

        expect(rebuilt.endDate, isNull);
        expect(rebuilt.isOngoing, isFalse);
      },
    );

    test('isOngoing se infiere de endDate cuando no se pasa explícito', () {
      final ongoing = FoodRecord(petId: 'pet-1', foodName: 'Croquetas', endDate: null);
      final stopped = FoodRecord(
        petId: 'pet-1',
        foodName: 'Croquetas',
        endDate: DateTime(2026, 3, 1),
      );

      expect(ongoing.isOngoing, isTrue);
      expect(stopped.isOngoing, isFalse);
    });
  });

  group('FoodRecord isOngoing=true con endDate concreto es una combinación inválida', () {
    test('el constructor lo rechaza vía assert', () {
      expect(
        () => FoodRecord(
          petId: 'pet-1',
          foodName: 'Croquetas',
          endDate: DateTime(2026, 3, 1),
          isOngoing: true,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('FoodRecord.copyWith e isOngoing', () {
    test('pasar un endDate nuevo sin tocar isOngoing lo infiere en false', () {
      final record = FoodRecord(petId: 'pet-1', foodName: 'Croquetas');
      expect(record.isOngoing, isTrue);

      final updated = record.copyWith(endDate: DateTime(2026, 3, 1));

      expect(updated.isOngoing, isFalse);
      expect(updated.endDate, DateTime(2026, 3, 1));
    });

    test(
      'copyWith que no toca endDate ni isOngoing preserva isOngoing=false '
      'explícito -no lo vuelve a derivar de endDate==null-',
      () {
        final record = FoodRecord(
          petId: 'pet-1',
          foodName: 'Croquetas',
          endDate: null,
          isOngoing: false,
        );

        final updated = record.copyWith(notes: 'Ya no la come, no recuerdo desde cuándo');

        expect(updated.isOngoing, isFalse);
        expect(updated.endDate, isNull);
      },
    );

    test('copyWith(isOngoing: false) explícito cambia de "sigue comiendo" a "fecha desconocida"', () {
      final record = FoodRecord(petId: 'pet-1', foodName: 'Croquetas');
      expect(record.isOngoing, isTrue);

      final updated = record.copyWith(isOngoing: false);

      expect(updated.isOngoing, isFalse);
      expect(updated.endDate, isNull);
    });
  });

  group('foodRecordStatusText', () {
    test('sigue comiendo', () {
      final record = FoodRecord(petId: 'pet-1', foodName: 'Croquetas');
      expect(foodRecordStatusText(record), 'Sigue comiendo');
    });

    test('dejó de comerlo, fecha desconocida', () {
      final record = FoodRecord(
        petId: 'pet-1',
        foodName: 'Croquetas',
        endDate: null,
        isOngoing: false,
      );
      expect(foodRecordStatusText(record), 'Dejó de comerlo (fecha desconocida)');
    });

    test('dejó de comerlo, fecha conocida', () {
      final record = FoodRecord(
        petId: 'pet-1',
        foodName: 'Croquetas',
        endDate: DateTime(2026, 3, 1),
      );
      expect(foodRecordStatusText(record), 'Hasta 01/03/2026');
    });
  });

  group('FoodRecord.getEventsFromList', () {
    test('con startDate y endDate genera ambos eventos', () {
      final records = [
        FoodRecord(
          id: 1,
          petId: 'pet-1',
          foodName: 'Croquetas',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 3, 1),
        ),
      ];

      final events = FoodRecord.getEventsFromList(records);

      expect(events, hasLength(2));
      expect(events[0]['type'], 'food_record');
      expect(events[0]['title'], 'Inicio de alimento: Croquetas');
      expect(events[0]['date'], DateTime(2026, 1, 1));
      expect(events[1]['type'], 'food_record_end');
      expect(events[1]['title'], 'Fin de alimento: Croquetas');
      expect(events[1]['date'], DateTime(2026, 3, 1));
    });

    test(
      'con startDate null pero endDate presente, igual genera el evento de '
      'fin -no se suprime solo porque falta el de inicio-',
      () {
        final records = [
          FoodRecord(
            id: 1,
            petId: 'pet-1',
            foodName: 'Croquetas',
            startDate: null,
            endDate: DateTime(2026, 3, 1),
          ),
        ];

        final events = FoodRecord.getEventsFromList(records);

        expect(events, hasLength(1));
        expect(events.single['type'], 'food_record_end');
        expect(events.single['title'], 'Fin de alimento: Croquetas');
      },
    );

    test('con startDate presente pero endDate null, solo genera el evento de inicio', () {
      final records = [
        FoodRecord(
          id: 1,
          petId: 'pet-1',
          foodName: 'Croquetas',
          startDate: DateTime(2026, 1, 1),
          endDate: null,
        ),
      ];

      final events = FoodRecord.getEventsFromList(records);

      expect(events, hasLength(1));
      expect(events.single['type'], 'food_record');
      expect(events.single['title'], 'Inicio de alimento: Croquetas');
    });

    test('con ambas fechas null, no genera ningún evento', () {
      final records = [
        FoodRecord(id: 1, petId: 'pet-1', foodName: 'Croquetas'),
      ];

      expect(FoodRecord.getEventsFromList(records), isEmpty);
    });

    test('devuelve una lista vacía si no hay registros', () {
      expect(FoodRecord.getEventsFromList([]), isEmpty);
    });
  });
}
