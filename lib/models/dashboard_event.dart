import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/medication_intake.dart';

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
    this.isTaken = false,
  });

  final String petId;
  final String petName;
  final String? petImageUrl;
  final DateTime date;
  final String title;
  final String type;
  final bool isTaken;

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
  /// todo el historial). Acá se deduplica a UN 'next_deworming' y UN
  /// 'next_vaccination' POR NOMBRE de producto/vacuna: el correspondiente
  /// al registro con la fecha de aplicación ('date') más reciente de ESE
  /// nombre. El resto (aplicaciones viejas ya superadas por una más nueva
  /// del mismo producto) se descarta.
  ///
  /// Importante: la dedup es por nombre, no un único ganador para toda la
  /// mascota — una mascota puede tener varias vacunas/productos distintos
  /// en paralelo (ej. rabia vencida en agosto y polivalente vencida el año
  /// que viene), y cada uno necesita su propio "próxima dosis" visible.
  static List<DashboardEvent> fromEventMaps(
    List<Map<String, dynamic>> rawEvents,
    Pet pet, {
    List<MedicationIntake> intakes = const [],
  }) {
    final events = <DashboardEvent>[];

    final dewormingWinnerIds =
        _idsOfMostRecentApplicationPerName(rawEvents, 'deworming');
    final vaccinationWinnerIds =
        _idsOfMostRecentApplicationPerName(rawEvents, 'vaccination');
    // 'next_vaccination' usa '${vaccination.id}_next' as id (ver
    // Vaccination.getEventsFromList), a diferencia de 'next_deworming' que
    // reutiliza el mismo id que su registro de aplicación.
    final nextVaccinationWinnerIds =
        vaccinationWinnerIds.map((id) => '${id}_next').toSet();

    for (final raw in rawEvents) {
      final type = raw['type'] as String?;
      if (type == null || !actionableDashboardEventTypes.contains(type)) {
        continue;
      }
      if (type == 'appointment' && raw['isCompleted'] == true) {
        continue;
      }
      if (type == 'next_deworming' && !dewormingWinnerIds.contains(raw['id'])) {
        continue;
      }
      if (type == 'next_vaccination' &&
          !nextVaccinationWinnerIds.contains(raw['id'])) {
        continue;
      }

      final date = raw['date'];
      if (date is! DateTime) continue;

      // ✅ Lógica inteligente de toma
      bool isTaken = false;
      if (type == 'medication_end') {
        final medName = (raw['title'] as String? ?? '')
            .replaceFirst('Fin de medicación: ', '')
            .replaceFirst('Fin de medicación de ${pet.name}: ', '');
        isTaken = intakes.any((i) =>
            i.medicationName == medName &&
            i.intakeDateTime.year == date.year &&
            i.intakeDateTime.month == date.month &&
            i.intakeDateTime.day == date.day);
      }

      events.add(DashboardEvent(
        petId: pet.id,
        petName: pet.name,
        petImageUrl: pet.imageUrl,
        date: date,
        title: raw['title'] as String? ?? '',
        type: type,
        isTaken: isTaken,
      ));
    }

    return events;
  }

  /// Para cada nombre distinto de producto/vacuna entre los registros de
  /// tipo [applicationType] ('deworming' o 'vaccination'), el id del
  /// registro con la fecha de aplicación más reciente. Agrupar por nombre
  /// es lo que permite que dos vacunas distintas (ej. "Rabia" y
  /// "Polivalente") tengan cada una su propia "próxima dosis" vigente, en
  /// vez de que la más recientemente aplicada tape a las demás.
  static Set<dynamic> _idsOfMostRecentApplicationPerName(
    List<Map<String, dynamic>> rawEvents,
    String applicationType,
  ) {
    final latestByName = <String, Map<String, dynamic>>{};
    for (final raw in rawEvents) {
      if (raw['type'] != applicationType) continue;
      final date = raw['date'];
      if (date is! DateTime) continue;
      final name = raw['name'] as String? ?? '';
      final currentLatestDate = latestByName[name]?['date'] as DateTime?;
      if (currentLatestDate == null || date.isAfter(currentLatestDate)) {
        latestByName[name] = raw;
      }
    }
    return latestByName.values.map((raw) => raw['id']).toSet();
  }
}
