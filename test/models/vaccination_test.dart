// vaccinations_screen.dart decide qué registro muestra "Próxima dosis"
// combinando Vaccination.getEventsFromList con
// DashboardEvent.idsOfMostRecentApplicationPerName -el mismo criterio de
// agrupación por nombre de vacuna que ya usa el panel "Hoy"-. Estos tests
// cubren esa composición exacta, sin necesidad de un widget test.
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_pal/models/dashboard_event.dart';
import 'package:pet_pal/models/vaccination.dart';

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
  });
}
