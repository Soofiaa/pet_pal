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
  /// todo el historial). Acá se aplican dos reducciones antes de llegar al
  /// panel "Hoy":
  ///
  /// 1. Por NOMBRE de producto/vacuna, nos quedamos con el registro cuya
  ///    fecha de aplicación ('date') es la más reciente de ESE nombre — el
  ///    resto son aplicaciones viejas del MISMO producto ya superadas por
  ///    una más nueva.
  /// 2. Por TIPO de evento (appointment / next_vaccination /
  ///    next_deworming / medication_end), nos quedamos con uno solo por
  ///    mascota: el de fecha más próxima a futuro (o la menos vencida, si
  ///    todas las de ese tipo ya pasaron). El panel "Hoy" es un resumen de
  ///    qué es lo más urgente de cada tipo, no un timeline completo — si
  ///    hay varias citas o varias vacunas pendientes, solo se ve la más
  ///    próxima; a medida que se resuelve, la siguiente pasa a ocupar su
  ///    lugar.
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

    return _keepSoonestPerType(events);
  }

  /// Se queda con un único evento por tipo: el de fecha más próxima a
  /// futuro (hoy cuenta como futuro) o, si todos los de ese tipo ya están
  /// vencidos, el menos vencido (el que pasó más recientemente) — así una
  /// tarea atrasada sigue siendo visible en vez de desaparecer del panel.
  static List<DashboardEvent> _keepSoonestPerType(
    List<DashboardEvent> events,
  ) {
    final winnerByType = <String, DashboardEvent>{};
    for (final event in events) {
      final current = winnerByType[event.type];
      if (current == null || _isSoonerForPanel(event, current)) {
        winnerByType[event.type] = event;
      }
    }
    return winnerByType.values.toList();
  }

  static bool _isSoonerForPanel(DashboardEvent a, DashboardEvent b) {
    final aOverdue = a.urgency == DashboardUrgency.overdue;
    final bOverdue = b.urgency == DashboardUrgency.overdue;
    if (aOverdue != bOverdue) return !aOverdue;
    return aOverdue ? a.date.isAfter(b.date) : a.date.isBefore(b.date);
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
