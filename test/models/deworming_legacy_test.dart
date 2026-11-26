import 'package:flutter_test/flutter_test.dart';
import 'package:pet_pal/models/dashboard_event.dart';
import 'package:pet_pal/models/deworming.dart';
import 'package:pet_pal/models/pet.dart';

void main() {
  group('Deworming - Reglas de legados (type: null)', () {
    test('neverRecordedCoverageTypes: solo interna con tipo -> reporta {externa}', () {
      final interna = Deworming(
        id: '1',
        petId: 'p',
        product: 'I',
        date: DateTime(2026, 1, 1),
        type: 'interna',
      );
      expect(Deworming.neverRecordedCoverageTypes([interna]), {'externa'});
    });

    test('neverRecordedCoverageTypes: interna con tipo + legado -> reporta {}', () {
      final interna = Deworming(
        id: '1',
        petId: 'p',
        product: 'I',
        date: DateTime(2026, 1, 1),
        type: 'interna',
      );
      final legado = Deworming(
        id: '2',
        petId: 'p',
        product: 'L',
        date: DateTime(2026, 1, 1),
        type: null,
      );
      expect(Deworming.neverRecordedCoverageTypes([interna, legado]), isEmpty);
    });

    test('neverRecordedCoverageTypes: solo legados -> reporta {}', () {
      final legado = Deworming(
        id: '1',
        petId: 'p',
        product: 'L',
        date: DateTime(2026, 1, 1),
        type: null,
      );
      expect(Deworming.neverRecordedCoverageTypes([legado]), isEmpty);
    });

    test('idsWithVisibleNextDose: único legado -> ganador', () {
      final legado = Deworming(
        id: 'leg',
        petId: 'p',
        product: 'L',
        date: DateTime(2026, 1, 1),
        nextDate: DateTime(2026, 4, 1),
        type: null,
      );
      expect(Deworming.idsWithVisibleNextDose([legado]), {'leg'});
    });

    test('idsWithVisibleNextDose: dos legados -> solo el más reciente', () {
      final viejo = Deworming(
        id: 'leg-1',
        petId: 'p',
        product: 'L1',
        date: DateTime(2025, 1, 1),
        type: null,
      );
      final nuevo = Deworming(
        id: 'leg-2',
        petId: 'p',
        product: 'L2',
        date: DateTime(2026, 1, 1),
        type: null,
      );
      expect(Deworming.idsWithVisibleNextDose([viejo, nuevo]), {'leg-2'});
    });

    test('idsWithVisibleNextDose: legado + interna posterior -> ambos ganadores', () {
      final legado = Deworming(
        id: 'leg',
        petId: 'p',
        product: 'L',
        date: DateTime(2026, 1, 1),
        type: null,
      );
      final interna = Deworming(
        id: 'int',
        petId: 'p',
        product: 'I',
        date: DateTime(2026, 2, 1),
        type: 'interna',
      );
      expect(Deworming.idsWithVisibleNextDose([legado, interna]), {'leg', 'int'});
    });

    test('idsWithVisibleNextDose: legado + externa posterior -> ambos ganadores', () {
      final legado = Deworming(
        id: 'leg',
        petId: 'p',
        product: 'L',
        date: DateTime(2026, 1, 1),
        type: null,
      );
      final externa = Deworming(
        id: 'ext',
        petId: 'p',
        product: 'E',
        date: DateTime(2026, 2, 1),
        type: 'externa',
      );
      expect(Deworming.idsWithVisibleNextDose([legado, externa]), {'leg', 'ext'});
    });

    test('idsWithVisibleNextDose: ambas anterior + legado posterior -> ambos ganadores', () {
      final ambas = Deworming(
        id: 'ambas',
        petId: 'p',
        product: 'A',
        date: DateTime(2025, 1, 1),
        type: 'ambas',
      );
      final legado = Deworming(
        id: 'leg',
        petId: 'p',
        product: 'L',
        date: DateTime(2026, 1, 1),
        type: null,
      );
      expect(Deworming.idsWithVisibleNextDose([ambas, legado]), {'ambas', 'leg'});
    });

    test('idsWithVisibleNextDose: legado + ambas posterior -> solo ambas', () {
      final legado = Deworming(
        id: 'leg',
        petId: 'p',
        product: 'L',
        date: DateTime(2025, 1, 1),
        type: null,
      );
      final ambas = Deworming(
        id: 'ambas',
        petId: 'p',
        product: 'A',
        date: DateTime(2026, 1, 1),
        type: 'ambas',
      );
      expect(Deworming.idsWithVisibleNextDose([legado, ambas]), {'ambas'});
    });

    test('idsWithVisibleNextDose: legado seguido de interna y externa posteriores -> legado superado', () {
      final legado = Deworming(
        id: 'leg',
        petId: 'p',
        product: 'L',
        date: DateTime(2026, 1, 1),
        type: null,
      );
      final interna = Deworming(
        id: 'int',
        petId: 'p',
        product: 'I',
        date: DateTime(2026, 2, 1),
        type: 'interna',
      );
      final externa = Deworming(
        id: 'ext',
        petId: 'p',
        product: 'E',
        date: DateTime(2026, 3, 1),
        type: 'externa',
      );

      final winners = Deworming.idsWithVisibleNextDose([legado, interna, externa]);
      expect(winners, {'int', 'ext'});
    });

    test('DashboardEvent.fromEventMaps: el panel Hoy no oculta next_deworming vencido de legado si solo hay interna posterior', () {
      final pet = Pet(
        id: 'p',
        name: 'Toby',
        species: 'Perro',
        breed: 'Mestizo',
        color: 'Negro',
        dob: DateTime(2020, 1, 1),
      );
      final now = DateTime.now();
      final legado = Deworming(
        id: 'leg',
        petId: 'p',
        product: 'LegadoViejo',
        date: now.subtract(const Duration(days: 60)),
        nextDate: now.subtract(const Duration(days: 10)),
        type: null,
      );
      final interna = Deworming(
        id: 'int',
        petId: 'p',
        product: 'InternaNueva',
        date: now.subtract(const Duration(days: 5)),
        nextDate: now.add(const Duration(days: 25)),
        type: 'interna',
      );

      final rawEvents = Deworming.getEventsFromList([legado, interna]);
      final dashboardEvents = DashboardEvent.fromEventMaps(rawEvents, pet);

      final titles = dashboardEvents.map((e) => e.title).toList();
      expect(titles, contains('Próxima desparasitación: LegadoViejo'));
      expect(titles, contains('Próxima desparasitación (I): InternaNueva'));
    });

    test('DashboardEvent.fromEventMaps: el panel Hoy SÍ oculta next_deworming vencido de legado si hay interna + externa posteriores', () {
      final pet = Pet(
        id: 'p',
        name: 'Toby',
        species: 'Perro',
        breed: 'Mestizo',
        color: 'Negro',
        dob: DateTime(2020, 1, 1),
      );
      final now = DateTime.now();
      final legado = Deworming(
        id: 'leg',
        petId: 'p',
        product: 'LegadoViejo',
        date: now.subtract(const Duration(days: 60)),
        nextDate: now.subtract(const Duration(days: 10)),
        type: null,
      );
      final interna = Deworming(
        id: 'int',
        petId: 'p',
        product: 'InternaNueva',
        date: now.subtract(const Duration(days: 5)),
        nextDate: now.add(const Duration(days: 25)),
        type: 'interna',
      );
      final externa = Deworming(
        id: 'ext',
        petId: 'p',
        product: 'ExternaNueva',
        date: now.subtract(const Duration(days: 3)),
        nextDate: now.add(const Duration(days: 27)),
        type: 'externa',
      );

      final rawEvents = Deworming.getEventsFromList([legado, interna, externa]);
      final dashboardEvents = DashboardEvent.fromEventMaps(rawEvents, pet);

      final titles = dashboardEvents.map((e) => e.title).toList();
      expect(titles, isNot(contains('Próxima desparasitación: LegadoViejo')));
    });

    test('interna + legado posterior: getEventsFromList conserva el evento next_deworming de la interna y ambos son ganadores', () {
      final now = DateTime.now();
      final interna = Deworming(
        id: 'int',
        petId: 'p',
        product: 'InternaVieja',
        date: now.subtract(const Duration(days: 30)),
        nextDate: now.add(const Duration(days: 60)),
        type: 'interna',
      );
      final legado = Deworming(
        id: 'leg',
        petId: 'p',
        product: 'LegadoNuevo',
        date: now.subtract(const Duration(days: 5)),
        nextDate: now.add(const Duration(days: 85)),
        type: null,
      );

      final dewormings = [interna, legado];
      
      // 1. Ambos son ganadores (el legado no tapa a la interna)
      final winners = Deworming.idsWithVisibleNextDose(dewormings);
      expect(winners, contains('int'));
      expect(winners, contains('leg'));

      // 2. getEventsFromList genera ambos eventos next_deworming
      final events = Deworming.getEventsFromList(dewormings);
      final nextEvents = events.where((e) => e['type'] == 'next_deworming');
      expect(nextEvents.length, 2);
      final titles = nextEvents.map((e) => e['title']).toList();
      expect(titles, contains('Próxima desparasitación (I): InternaVieja'));
      expect(titles, contains('Próxima desparasitación: LegadoNuevo'));
    });

    test('interna + legado posterior: getEventsFromList conserva next_deworming de interna e idsWithVisibleNextDose mantiene a ambos ganadores', () {
      final interna = Deworming(
        id: 'int',
        petId: 'p',
        product: 'InternaPrevia',
        date: DateTime(2026, 1, 1),
        nextDate: DateTime(2026, 4, 1),
        type: 'interna',
      );
      final legado = Deworming(
        id: 'leg',
        petId: 'p',
        product: 'LegadoPosterior',
        date: DateTime(2026, 2, 1),
        nextDate: DateTime(2026, 5, 1),
        type: null,
      );

      expect(Deworming.idsWithVisibleNextDose([interna, legado]), {'int', 'leg'});

      final events = Deworming.getEventsFromList([interna, legado]);
      final nextIds = events
          .where((e) => e['type'] == 'next_deworming')
          .map((e) => e['id'])
          .toSet();
      expect(nextIds, {'int', 'leg'});
    });
  });
}
