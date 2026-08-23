// Deworming.effectiveNextDate() es la única función que calcula el avance
// de "próxima desparasitación" para registros recurrentes -la usan
// ReminderScheduler, getEventsFromList (dashboard/calendario) y las
// pantallas de desparasitación por igual (ver add_edit_deworming_screen.dart
// y deworming_screen.dart)-, así que su corrección acá cubre los cuatro
// puntos de uso a la vez.
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_pal/models/deworming.dart';

Deworming _deworming({
  DateTime? nextDate,
  int? frequencyMonths,
  bool isRecurring = false,
}) {
  return Deworming(
    petId: 'pet-1',
    product: 'Producto X',
    date: DateTime(2026, 1, 1),
    nextDate: nextDate,
    frequencyMonths: frequencyMonths,
    isRecurring: isRecurring,
  );
}

void main() {
  group('Deworming.effectiveNextDate', () {
    test('sin nextDate, devuelve null', () {
      final deworming = _deworming(isRecurring: true, frequencyMonths: 3);
      expect(deworming.effectiveNextDate(now: DateTime(2026, 6, 1)), isNull);
    });

    test('no recurrente: devuelve nextDate sin cambios aunque esté vencido', () {
      final deworming = _deworming(
        nextDate: DateTime(2026, 3, 1),
        frequencyMonths: 3,
        isRecurring: false,
      );
      expect(
        deworming.effectiveNextDate(now: DateTime(2026, 9, 1)),
        DateTime(2026, 3, 1),
      );
    });

    test('recurrente sin frequencyMonths: se comporta como no recurrente', () {
      final deworming = _deworming(
        nextDate: DateTime(2026, 3, 1),
        frequencyMonths: null,
        isRecurring: true,
      );
      expect(
        deworming.effectiveNextDate(now: DateTime(2026, 9, 1)),
        DateTime(2026, 3, 1),
      );
    });

    test('recurrente, nextDate ya futura: no avanza (idempotente)', () {
      final deworming = _deworming(
        nextDate: DateTime(2026, 12, 1),
        frequencyMonths: 3,
        isRecurring: true,
      );
      expect(
        deworming.effectiveNextDate(now: DateTime(2026, 6, 1)),
        DateTime(2026, 12, 1),
      );
    });

    test('recurrente, un ciclo vencido: avanza exactamente un frequencyMonths', () {
      final deworming = _deworming(
        nextDate: DateTime(2026, 3, 1),
        frequencyMonths: 3,
        isRecurring: true,
      );
      // now cae después de 2026-03-01 pero antes de 2026-06-01.
      expect(
        deworming.effectiveNextDate(now: DateTime(2026, 4, 15)),
        DateTime(2026, 6, 1),
      );
    });

    test('recurrente, varios ciclos vencidos: avanza hasta la próxima ocurrencia futura', () {
      final deworming = _deworming(
        nextDate: DateTime(2026, 1, 1),
        frequencyMonths: 3,
        isRecurring: true,
      );
      // Han pasado ~8 meses (más de 2 ciclos de 3 meses) sin abrir la app.
      final result = deworming.effectiveNextDate(now: DateTime(2026, 9, 10));
      expect(result, DateTime(2026, 10, 1));
      expect(result!.isAfter(DateTime(2026, 9, 10)), isTrue);
    });

    test('recurrente, exactamente en la fecha límite: no avanza (>= now cuenta como vigente)', () {
      final deworming = _deworming(
        nextDate: DateTime(2026, 6, 1),
        frequencyMonths: 3,
        isRecurring: true,
      );
      expect(
        deworming.effectiveNextDate(now: DateTime(2026, 6, 1)),
        DateTime(2026, 6, 1),
      );
    });

    test('avance repetido converge al mismo resultado (persistir el valor mostrado es seguro)', () {
      final original = _deworming(
        nextDate: DateTime(2026, 1, 1),
        frequencyMonths: 2,
        isRecurring: true,
      );
      final now = DateTime(2026, 8, 1);

      final advancedOnce = original.effectiveNextDate(now: now)!;
      // Simula "guardar la fecha mostrada" y volver a leerla más tarde,
      // el mismo día: debe dar el mismo resultado que no haberla guardado.
      final resaved = _deworming(
        nextDate: advancedOnce,
        frequencyMonths: 2,
        isRecurring: true,
      );

      expect(resaved.effectiveNextDate(now: now), advancedOnce);
    });
  });

  group('Deworming.getEventsFromList', () {
    test('el evento next_deworming usa la fecha avanzada para un registro recurrente vencido', () {
      final deworming = Deworming(
        id: 'dew-1',
        petId: 'pet-1',
        product: 'Producto X',
        date: DateTime(2026, 1, 1),
        nextDate: DateTime(2026, 1, 1),
        frequencyMonths: 1,
        isRecurring: true,
      );

      final events = Deworming.getEventsFromList([deworming]);
      final nextEvent = events.firstWhere((e) => e['type'] == 'next_deworming');

      final DateTime eventDate = nextEvent['date'] as DateTime;
      expect(eventDate.isAfter(DateTime.now()), isTrue);
    });
  });
}
