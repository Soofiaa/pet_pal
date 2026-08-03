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
  ///
  /// `Deworming`/`Vaccination.getEventsFromList()` generan un evento
  /// 'next_X' por cada registro histórico que tenga fecha secundaria, no
  /// solo por el más reciente (correcto para el calendario, que quiere ver
  /// todo el historial). Acá se deduplica a UN solo 'next_deworming' y UN
  /// solo 'next_vaccination' por mascota: el correspondiente al registro
  /// con la fecha de aplicación ('date') más reciente. El resto se
  /// descarta por superado.
  static List<DashboardEvent> fromEventMaps(
    List<Map<String, dynamic>> rawEvents,
    Pet pet,
  ) {
    final events = <DashboardEvent>[];

    final dewormingWinnerId =
        _idOfMostRecentApplication(rawEvents, 'deworming');
    final vaccinationWinnerId =
        _idOfMostRecentApplication(rawEvents, 'vaccination');
    // 'next_vaccination' usa '${vaccination.id}_next' como id (ver
    // Vaccination.getEventsFromList), a diferencia de 'next_deworming' que
    // reutiliza el mismo id que su registro de aplicación.
    final nextVaccinationWinnerId =
        vaccinationWinnerId == null ? null : '${vaccinationWinnerId}_next';

    for (final raw in rawEvents) {
      final type = raw['type'] as String?;
      if (type == null || !actionableDashboardEventTypes.contains(type)) {
        continue;
      }
      if (type == 'appointment' && raw['isCompleted'] == true) {
        continue;
      }
      if (type == 'next_deworming' && raw['id'] != dewormingWinnerId) {
        continue;
      }
      if (type == 'next_vaccination' && raw['id'] != nextVaccinationWinnerId) {
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

  /// Id del registro de tipo [applicationType] ('deworming' o
  /// 'vaccination') con la fecha de aplicación más reciente, o `null` si no
  /// hay ninguno.
  static dynamic _idOfMostRecentApplication(
    List<Map<String, dynamic>> rawEvents,
    String applicationType,
  ) {
    Map<String, dynamic>? latest;
    for (final raw in rawEvents) {
      if (raw['type'] != applicationType) continue;
      final date = raw['date'];
      if (date is! DateTime) continue;
      final latestDate = latest?['date'] as DateTime?;
      if (latestDate == null || date.isAfter(latestDate)) {
        latest = raw;
      }
    }
    return latest?['id'];
  }
}
