import 'package:pet_pal/models/pet.dart';

/// Tipos de evento de [DatabaseHelper.getAllEventsForPet] que representan
/// algo pendiente de atención (recordatorio, vencimiento, fin de
/// tratamiento) en vez de un registro histórico ya ocurrido (ej. una
/// vacuna ya aplicada, una nota, un peso registrado). El dashboard "Hoy"
/// solo tiene sentido para estos tipos: incluir cada registro histórico lo
/// volvería un timeline completo en vez de un resumen de qué necesita
/// atención hoy.
const Set<String> actionableDashboardEventTypes = {
  'appointment',
  'next_vaccination',
  'next_deworming',
  'medication_end',
};

enum DashboardUrgency { overdue, today, upcoming, later }

class DashboardEvent {
  DashboardEvent({
    required this.petId,
    required this.petName,
    this.petImageUrl,
    required this.date,
    required this.title,
    required this.type,
  });

  final String petId;
  final String petName;
  final String? petImageUrl;
  final DateTime date;
  final String title;
  final String type;

  DashboardUrgency get urgency {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(date.year, date.month, date.day);
    final diffInDays = eventDay.difference(today).inDays;

    if (diffInDays < 0) return DashboardUrgency.overdue;
    if (diffInDays == 0) return DashboardUrgency.today;
    if (diffInDays <= 7) return DashboardUrgency.upcoming;
    return DashboardUrgency.later;
  }

  int get urgencyRank => urgency.index;

  /// Convierte los mapas sueltos de `getAllEventsForPet` en eventos
  /// tipados, quedándose solo con los tipos accionables y descartando
  /// citas ya marcadas como completadas.
  static List<DashboardEvent> fromEventMaps(
    List<Map<String, dynamic>> rawEvents,
    Pet pet,
  ) {
    final events = <DashboardEvent>[];

    for (final raw in rawEvents) {
      final type = raw['type'] as String?;
      if (type == null || !actionableDashboardEventTypes.contains(type)) {
        continue;
      }
      if (type == 'appointment' && raw['isCompleted'] == true) {
        continue;
      }

      final date = raw['date'];
      if (date is! DateTime) continue;

      events.add(DashboardEvent(
        petId: pet.id,
        petName: pet.name,
        petImageUrl: pet.imageUrl,
        date: date,
        title: raw['title'] as String? ?? '',
        type: type,
      ));
    }

    return events;
  }
}
