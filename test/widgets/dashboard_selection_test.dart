import 'package:flutter_test/flutter_test.dart';
import 'package:pet_pal/models/dashboard_event.dart';
import 'package:pet_pal/widgets/today_dashboard_section.dart';

DashboardEvent _event(String title, String petName, int days) => DashboardEvent(
      petId: petName,
      petName: petName,
      date: DateTime.now().add(Duration(days: days)),
      title: title,
      type: 'appointment',
    );

void main() {
  group('selectDashboardEvents', () {
    test('cuenta como ocultos los eventos que exceden el límite por mascota', () {
      // Una sola mascota con 4 eventos: se dibujan 2, quedan 2 ocultos.
      final events = [for (var i = 0; i < 4; i++) _event('E$i', 'Luna', i)];

      final selection = selectDashboardEvents(events);

      expect(selection.visibleByPet['Luna'], hasLength(2));
      expect(selection.hiddenCount, 2);
    });

    test('cuenta como ocultos los eventos de mascotas más allá del límite', () {
      final events = [
        for (final pet in ['A', 'B', 'C', 'D']) _event('E-$pet', pet, 1),
      ];

      final selection = selectDashboardEvents(events);

      expect(selection.visibleByPet.keys, ['A', 'B', 'C']);
      expect(selection.hiddenCount, 1);
    });

    test('no oculta nada cuando todo cabe', () {
      final events = [_event('E0', 'Luna', 0), _event('E1', 'Milo', 1)];

      final selection = selectDashboardEvents(events);

      expect(selection.hiddenCount, 0);
    });
  });
}
