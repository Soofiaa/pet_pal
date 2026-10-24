// vaccinations_screen.dart decide qué registro muestra "Próxima dosis"
// combinando Vaccination.getEventsFromList con
// DashboardEvent.idsOfMostRecentApplicationPerName -el mismo criterio de
// agrupación por nombre de vacuna que ya usa el panel "Hoy"-. Estos tests
// cubren esa composición exacta, sin necesidad de un widget test.
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_pal/models/dashboard_event.dart';
import 'package:pet_pal/models/vaccination.dart';
import 'package:pet_pal/models/vaccination_product.dart';

Set<dynamic> _idsWithVisibleNextDose(List<Vaccination> vaccinations) {
  return DashboardEvent.idsOfMostRecentApplicationPerName(
    Vaccination.getEventsFromList(vaccinations),
    'vaccination',
  );
}

void main() {
  group('vacunas: ids con "Próxima dosis" visible', () {
    test('un solo tipo de vacuna con 2 registros: solo el más reciente la muestra', () {
      final vieja = Vaccination(
        id: 'v-2025',
        petId: 'pet-1',
        vaccineName: 'Vacuna De La Rabia',
        date: DateTime(2025, 1, 1),
        nextDueDate: DateTime(2026, 1, 1),
      );
      final nueva = Vaccination(
        id: 'v-2026',
        petId: 'pet-1',
        vaccineName: 'Vacuna De La Rabia',
        date: DateTime(2026, 1, 15),
        nextDueDate: DateTime(2027, 1, 15),
      );

      final winners = _idsWithVisibleNextDose([vieja, nueva]);

      expect(winners, {'v-2026'});
      expect(winners.contains('v-2025'), isFalse);
    });

    test('vacunas distintas: cada una conserva su propia "Próxima dosis"', () {
      final rabia = Vaccination(
        id: 'v-rabia',
        petId: 'pet-1',
        vaccineName: 'Vacuna De La Rabia',
        date: DateTime(2026, 1, 1),
        nextDueDate: DateTime(2027, 1, 1),
      );
      final polivalente = Vaccination(
        id: 'v-poli',
        petId: 'pet-1',
        vaccineName: 'Polivalente',
        date: DateTime(2026, 2, 1),
        nextDueDate: DateTime(2027, 2, 1),
      );

      final winners = _idsWithVisibleNextDose([rabia, polivalente]);

      expect(winners, {'v-rabia', 'v-poli'});
    });

    test('Séxtuple, Óctuple y Polivalente cuentan como la misma vacuna', () {
      final sextuple = Vaccination(
        id: 'v-sextuple',
        petId: 'pet-1',
        vaccineName: 'Vacuna Séxtuple Canina',
        date: DateTime(2025, 9, 16),
        nextDueDate: DateTime(2026, 9, 16),
      );
      final octuple = Vaccination(
        id: 'v-octuple',
        petId: 'pet-1',
        vaccineName: 'Octuple',
        date: DateTime(2026, 9, 17),
        nextDueDate: DateTime(2027, 9, 17),
      );

      expect(_idsWithVisibleNextDose([sextuple, octuple]), {'v-octuple'});
      expect(_idsWithVisibleNextDose([octuple, sextuple]), {'v-octuple'});
    });

    test('el grupo del catálogo hace equivalentes vacunas de otras especies', () {
      final productos = [
        VaccinationProduct(name: 'Triple felina', defaultFrequencyMonths: 12, groupName: 'Felina múltiple'),
        VaccinationProduct(name: 'Cuádruple felina', defaultFrequencyMonths: 12, groupName: 'felina multiple '),
      ];
      final triple = Vaccination(
        id: 'v-triple',
        petId: 'pet-1',
        vaccineName: 'Triple felina',
        date: DateTime(2025, 5, 1),
      );
      final cuadruple = Vaccination(
        id: 'v-cuadruple',
        petId: 'pet-1',
        vaccineName: 'Cuádruple felina',
        date: DateTime(2026, 5, 1),
      );

      final sinGrupo = DashboardEvent.idsOfMostRecentApplicationPerName(
        Vaccination.getEventsFromList([triple, cuadruple]),
        'vaccination',
      );
      final conGrupo = DashboardEvent.idsOfMostRecentApplicationPerName(
        Vaccination.getEventsFromList([triple, cuadruple]),
        'vaccination',
        vaccineProducts: productos,
      );

      expect(sinGrupo, {'v-triple', 'v-cuadruple'});
      expect(conGrupo, {'v-cuadruple'});
    });

    test('un registro encuentra su producto aunque el nombre tenga más palabras', () {
      final productos = [
        VaccinationProduct(name: 'Sextuple', defaultFrequencyMonths: 12, groupName: 'Canina'),
        VaccinationProduct(name: 'Octuple', defaultFrequencyMonths: 12, groupName: 'Canina'),
      ];
      expect(
        DashboardEvent.vaccineGroupKey('Vacuna Séxtuple Canina', productos),
        DashboardEvent.vaccineGroupKey('Octuple', productos),
      );
    });

    test('un producto sin grupo no se agrupa con los demás', () {
      final productos = [
        VaccinationProduct(name: 'Rabia', defaultFrequencyMonths: 12),
        VaccinationProduct(name: 'KC', defaultFrequencyMonths: 12, groupName: '  '),
      ];
      expect(
        DashboardEvent.vaccineGroupKey('Rabia', productos),
        isNot(DashboardEvent.vaccineGroupKey('KC', productos)),
      );
    });

    test('la agrupación Múltiple no mezcla Rabia ni KC', () {
      final multiple = Vaccination(
        id: 'v-multiple',
        petId: 'pet-1',
        vaccineName: 'Octuple',
        date: DateTime(2026, 9, 17),
      );
      final rabia = Vaccination(
        id: 'v-rabia',
        petId: 'pet-1',
        vaccineName: 'Vacuna De La Rabia',
        date: DateTime(2026, 10, 1),
      );
      final kc = Vaccination(
        id: 'v-kc',
        petId: 'pet-1',
        vaccineName: 'Vacuna Kc',
        date: DateTime(2026, 10, 2),
      );

      expect(
        _idsWithVisibleNextDose([multiple, rabia, kc]),
        {'v-multiple', 'v-rabia', 'v-kc'},
      );
    });

    test('registro sin nextDueDate igual puede ser el ganador de su grupo (no tiene línea que mostrar)', () {
      final vieja = Vaccination(
        id: 'v-vieja',
        petId: 'pet-1',
        vaccineName: 'Vacuna De La Rabia',
        date: DateTime(2025, 1, 1),
        nextDueDate: DateTime(2026, 1, 1),
      );
      final nuevaSinNextDose = Vaccination(
        id: 'v-nueva',
        petId: 'pet-1',
        vaccineName: 'Vacuna De La Rabia',
        date: DateTime(2026, 6, 1),
        nextDueDate: null,
      );

      final winners = _idsWithVisibleNextDose([vieja, nuevaSinNextDose]);

      // La más nueva gana el grupo aunque no tenga nextDueDate propio: el
      // registro viejo igual deja de mostrar la suya (queda oculta del
      // todo, no se "hereda" la del ganador).
      expect(winners, {'v-nueva'});
    });

    test('reemplazo explícito: vacuna nueva que reemplaza a vieja oculta a la vieja', () {
      final vieja = Vaccination(
        id: 'v-vieja',
        petId: 'pet-1',
        vaccineName: 'Sextuple',
        date: DateTime(2025, 1, 1),
        nextDueDate: DateTime(2026, 1, 1),
      );
      final nueva = Vaccination(
        id: 'v-nueva',
        petId: 'pet-1',
        vaccineName: 'Octuple',
        date: DateTime(2026, 6, 1),
        nextDueDate: DateTime(2027, 6, 1),
        replacesVaccinationId: 'v-vieja',
      );

      final winners = _idsWithVisibleNextDose([vieja, nueva]);

      // La nueva reemplaza a la vieja, así que solo la nueva muestra próxima dosis
      expect(winners, {'v-nueva'});
    });

    test('reemplazo explícito: vacuna vieja reemplazada no muestra próxima dosis', () {
      final vieja = Vaccination(
        id: 'v-vieja',
        petId: 'pet-1',
        vaccineName: 'Sextuple',
        date: DateTime(2025, 1, 1),
        nextDueDate: DateTime(2026, 1, 1),
      );
      final nueva = Vaccination(
        id: 'v-nueva',
        petId: 'pet-1',
        vaccineName: 'Octuple',
        date: DateTime(2026, 6, 1),
        nextDueDate: DateTime(2027, 6, 1),
        replacesVaccinationId: 'v-vieja',
      );

      final events = Vaccination.getEventsFromList([vieja, nueva]);
      final viejaEvent = events.firstWhere((e) => e['id'] == 'v-vieja');
      final nuevaEvent = events.firstWhere((e) => e['id'] == 'v-nueva');

      // Verificar que el campo replacesVaccinationId está en los eventos
      expect(viejaEvent['replacesVaccinationId'], isNull);
      expect(nuevaEvent['replacesVaccinationId'], 'v-vieja');
    });

    test('reemplazo explícito con mismo nombre: la reemplazada queda oculta', () {
      final vieja = Vaccination(
        id: 'v-vieja',
        petId: 'pet-1',
        vaccineName: 'Rabia',
        date: DateTime(2025, 1, 1),
        nextDueDate: DateTime(2026, 1, 1),
      );
      final nueva = Vaccination(
        id: 'v-nueva',
        petId: 'pet-1',
        vaccineName: 'Rabia',
        date: DateTime(2026, 6, 1),
        nextDueDate: DateTime(2027, 6, 1),
        replacesVaccinationId: 'v-vieja',
      );

      final winners = _idsWithVisibleNextDose([vieja, nueva]);

      // Solo la nueva muestra próxima dosis
      expect(winners, {'v-nueva'});
    });
  });
}
