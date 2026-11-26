// Deworming.effectiveNextDate() es la fecha pendiente mostrada (UI,
// getEventsFromList, PDF). NO avanza por calendario: una recurrente vencida
// sigue vencida hasta que un registro nuevo la superseda. El avance para
// notificaciones vive en schedulingCycleIndex + occurrenceForCycle.
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

    test('no recurrente con nextDate pasada: sin cambios', () {
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

    test('recurrente con nextDate futura: devuelve esa fecha, sin cambios', () {
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

    test('recurrente con nextDate ayer y now hoy: devuelve ayer, no el ciclo siguiente', () {
      final deworming = _deworming(
        nextDate: DateTime(2026, 11, 24),
        frequencyMonths: 1,
        isRecurring: true,
      );
      expect(
        deworming.effectiveNextDate(now: DateTime(2026, 11, 25)),
        DateTime(2026, 11, 24),
      );
    });

    test('recurrente, varios ciclos vencidos: no avanza solo por el paso del tiempo', () {
      final deworming = _deworming(
        nextDate: DateTime(2026, 1, 1),
        frequencyMonths: 3,
        isRecurring: true,
      );
      expect(
        deworming.effectiveNextDate(now: DateTime(2026, 9, 10)),
        DateTime(2026, 1, 1),
      );
    });

    test('próxima = hoy (con hora ya pasada): sigue siendo la fecha vigente', () {
      final deworming = _deworming(
        nextDate: DateTime(2026, 10, 24),
        frequencyMonths: 1,
        isRecurring: true,
      );
      expect(
        deworming.effectiveNextDate(now: DateTime(2026, 10, 24, 15, 30)),
        DateTime(2026, 10, 24),
      );
    });
  });

  group('Deworming.schedulingCycleIndex / occurrenceForCycle', () {
    test('scheduler salta ciclos pasados para preprogramar futuros', () {
      final deworming = _deworming(
        nextDate: DateTime(2026, 3, 1),
        frequencyMonths: 3,
        isRecurring: true,
      );
      expect(deworming.schedulingCycleIndex(now: DateTime(2026, 4, 15)), 1);
      expect(
        deworming.occurrenceForCycle(1),
        DateTime(2026, 6, 1),
      );
    });

    test('día 31 + 1 mes: usa el último día del mes siguiente, no el 1 del otro', () {
      final deworming = _deworming(
        nextDate: DateTime(2026, 8, 31),
        frequencyMonths: 1,
        isRecurring: true,
      );
      expect(deworming.occurrenceForCycle(1), DateTime(2026, 9, 30));
    });
  });

  group('Deworming.idsWithVisibleNextDose', () {
    test('el más reciente cubre AMBOS: resetea la cobertura, solo él muestra "Próxima dosis"', () {
      final vieaInterna = Deworming(
        id: 'd-interna-vieja',
        petId: 'pet-1',
        product: 'Interno viejo',
        date: DateTime(2025, 1, 1),
        nextDate: DateTime(2025, 4, 1),
        type: 'interna',
      );
      final viejaExterna = Deworming(
        id: 'd-externa-vieja',
        petId: 'pet-1',
        product: 'Externo viejo',
        date: DateTime(2025, 2, 1),
        nextDate: DateTime(2025, 5, 1),
        type: 'externa',
      );
      final masReciente = Deworming(
        id: 'd-ambas',
        petId: 'pet-1',
        product: 'Nexgard Spectra',
        date: DateTime(2026, 1, 1),
        nextDate: DateTime(2026, 4, 1),
        type: 'ambas',
      );

      final winners = Deworming.idsWithVisibleNextDose(
        [vieaInterna, viejaExterna, masReciente],
      );

      expect(winners, {'d-ambas'});
    });

    test('el más reciente cubre solo un tipo: busca el más reciente del otro tipo por separado', () {
      final internaReciente = Deworming(
        id: 'd-interna-nueva',
        petId: 'pet-1',
        product: 'Desparasitante interno',
        date: DateTime(2026, 6, 1),
        nextDate: DateTime(2026, 9, 1),
        type: 'interna',
      );
      final externaAntigua = Deworming(
        id: 'd-externa-vieja',
        petId: 'pet-1',
        product: 'Simparica',
        date: DateTime(2024, 1, 1),
        nextDate: DateTime(2024, 4, 1),
        type: 'externa',
      );
      final internaMasVieja = Deworming(
        id: 'd-interna-vieja',
        petId: 'pet-1',
        product: 'Desparasitante interno viejo',
        date: DateTime(2023, 1, 1),
        nextDate: DateTime(2023, 4, 1),
        type: 'interna',
      );

      final winners = Deworming.idsWithVisibleNextDose(
        [internaReciente, externaAntigua, internaMasVieja],
      );

      expect(winners, {'d-interna-nueva', 'd-externa-vieja'});
      expect(winners.contains('d-interna-vieja'), isFalse);
    });

    test('un registro "ambas" antiguo cuenta como cobertura del otro tipo si es el más reciente de ese tipo', () {
      final internaReciente = Deworming(
        id: 'd-interna-nueva',
        petId: 'pet-1',
        product: 'Desparasitante interno',
        date: DateTime(2026, 6, 1),
        nextDate: DateTime(2026, 9, 1),
        type: 'interna',
      );
      final ambasAntigua = Deworming(
        id: 'd-ambas-vieja',
        petId: 'pet-1',
        product: 'Nexgard Spectra viejo',
        date: DateTime(2024, 1, 1),
        nextDate: DateTime(2024, 4, 1),
        type: 'ambas',
      );

      final winners = Deworming.idsWithVisibleNextDose(
        [internaReciente, ambasAntigua],
      );

      expect(winners, {'d-interna-nueva', 'd-ambas-vieja'});
    });

    test('sin registros con type reconocido: no hay ganadores', () {
      final legado = Deworming(
        id: 'd-legado',
        petId: 'pet-1',
        product: 'Producto legado',
        date: DateTime(2026, 1, 1),
        nextDate: DateTime(2026, 4, 1),
        type: null,
      );

      expect(Deworming.idsWithVisibleNextDose([legado]), isEmpty);
    });
  });

  group('Deworming.neverRecordedCoverageTypes', () {
    test('nunca hubo registro externo ni combinado: alerta por "externa"', () {
      final soloInterna = Deworming(
        id: 'd-1',
        petId: 'pet-1',
        product: 'Producto interno',
        date: DateTime(2026, 1, 1),
        type: 'interna',
      );

      expect(
        Deworming.neverRecordedCoverageTypes([soloInterna]),
        {'externa'},
      );
    });

    test('un registro "ambas" cubre huecos de ambos tipos', () {
      final ambas = Deworming(
        id: 'd-1',
        petId: 'pet-1',
        product: 'Nexgard Spectra',
        date: DateTime(2026, 1, 1),
        type: 'ambas',
      );

      expect(Deworming.neverRecordedCoverageTypes([ambas]), isEmpty);
    });

    test('sin ningún registro: faltan ambos tipos', () {
      expect(
        Deworming.neverRecordedCoverageTypes(const []),
        {'interna', 'externa'},
      );
    });
  });

  group('Deworming.getEventsFromList', () {
    test('el evento next_deworming de un recurrente vencido conserva la fecha original', () {
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

      expect(nextEvent['date'], DateTime(2026, 1, 1));
    });
  });
}
