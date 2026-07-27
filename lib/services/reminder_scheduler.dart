// reminder_scheduler.dart
import 'package:intl/intl.dart';
import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/appointment.dart';
import 'package:pet_pal/models/deworming.dart';
import 'package:pet_pal/models/medication.dart';
import 'package:pet_pal/models/vaccination.dart';
import 'package:pet_pal/services/notification_service.dart';

/// Punto único donde se decide CUÁNDO y con QUÉ id se programa cada
/// recordatorio (medicación, vacuna, desparasitación, cita). Se usa tanto
/// desde las pantallas de alta/edición/borrado como desde [rescheduleAllPending],
/// para garantizar que ambos caminos usen siempre los mismos ids y sean
/// idempotentes entre sí.
class ReminderScheduler {
  ReminderScheduler._();

  static const int _reminderHour = 9;

  static DateTime _atReminderHour(DateTime date) =>
      DateTime(date.year, date.month, date.day, _reminderHour);

  static int _medicationBaseId(String medicationId) =>
      medicationId.hashCode.abs() % 100000;

  /// Id determinístico por combinación única de medicación + horario + día,
  /// para el caso con endDate. Se usa una clave de texto hasheada en vez de
  /// aritmética con multiplicador fijo (baseId*1000+día) porque esa
  /// aritmética colisiona entre horarios distintos una vez que el
  /// tratamiento dura 1000 días o más.
  static int _medicationTimedDayId(
          String medicationId, int timeIndex, int dayIndex) =>
      '${medicationId}_${timeIndex}_$dayIndex'.hashCode;

  /// Id de la alarma repetible por horario, para el caso sin endDate.
  static int _medicationRepeatingId(String medicationId, int timeIndex) =>
      '${medicationId}_$timeIndex'.hashCode;

  static int _medicationDayCount(DateTime startDate, DateTime? endDate) {
    if (endDate == null) return 1;
    final int diff = endDate.difference(startDate).inDays;
    return diff < 0 ? 1 : diff + 1;
  }

  static (int, int) _parseHHmm(String value) {
    final parts = value.split(':');
    return (int.parse(parts[0]), int.parse(parts[1]));
  }

  /// Primera vez futura en la que debe sonar una alarma repetible diaria,
  /// sin disparar antes de que el tratamiento realmente empiece.
  static DateTime _firstOccurrenceOnOrAfterStart(
    DateTime startDate,
    int hour,
    int minute,
    DateTime now,
  ) {
    final DateTime todayAtTime =
        DateTime(now.year, now.month, now.day, hour, minute);
    final DateTime nextFromNow = todayAtTime.isBefore(now)
        ? todayAtTime.add(const Duration(days: 1))
        : todayAtTime;
    final DateTime startAtTime =
        DateTime(startDate.year, startDate.month, startDate.day, hour, minute);
    return nextFromNow.isAfter(startAtTime) ? nextFromNow : startAtTime;
  }

  static String _legacyBody(Medication medication) {
    final String freq = medication.frequency.trim();
    return freq.isEmpty
        ? 'Dosis: ${medication.dosage}'
        : 'Dosis: ${medication.dosage} · $freq';
  }

  static String _timedBody(Medication medication, String timeLabel) {
    final String freq = medication.frequency.trim();
    final String base = 'Toma de las $timeLabel — Dosis: ${medication.dosage}';
    return freq.isEmpty ? base : '$base · $freq';
  }

  static Future<void> cancelMedicationReminders(Medication medication) async {
    if (medication.id == null) return;
    final String id = medication.id!;

    if (medication.reminderTimes.isEmpty) {
      // Recordatorio único legado (9:00 AM, sin horarios definidos).
      await NotificationService().cancelMedicationForDays(
        baseId: _medicationBaseId(id),
        days: _medicationDayCount(medication.startDate, medication.endDate),
      );
      return;
    }

    final int dayCount =
        _medicationDayCount(medication.startDate, medication.endDate);

    for (int i = 0; i < medication.reminderTimes.length; i++) {
      if (medication.endDate != null) {
        for (int day = 0; day < dayCount; day++) {
          await NotificationService()
              .cancelNotification(_medicationTimedDayId(id, i, day));
        }
      } else {
        await NotificationService()
            .cancelNotification(_medicationRepeatingId(id, i));
      }
    }
  }

  /// Si la medicación no tiene horarios definidos (reminderTimes vacío),
  /// conserva el comportamiento legado: un recordatorio diario a las 9:00
  /// desde startDate hasta endDate (o solo el día de inicio si no hay
  /// endDate). Esto es lo que mantiene funcionando a las medicaciones
  /// creadas antes de que existiera este campo.
  ///
  /// Si tiene horarios definidos, programa cada uno por separado:
  /// - con endDate: una notificación por día y por horario, entre
  ///   startDate y endDate inclusive.
  /// - sin endDate: una alarma repetible diaria por horario (no se
  ///   pre-programa día por día), que sigue sonando hasta que se cancele.
  static Future<void> scheduleMedicationReminders(Medication medication) async {
    if (medication.id == null) return;
    final String id = medication.id!;

    if (medication.reminderTimes.isEmpty) {
      await NotificationService().scheduleMedicationForDays(
        baseId: _medicationBaseId(id),
        title: 'Recordatorio de medicación: ${medication.name}',
        body: _legacyBody(medication),
        firstDoseDateTime: _atReminderHour(medication.startDate),
        days: _medicationDayCount(medication.startDate, medication.endDate),
        payload: id,
      );
      return;
    }

    final DateTime now = DateTime.now();
    final int dayCount =
        _medicationDayCount(medication.startDate, medication.endDate);

    for (int i = 0; i < medication.reminderTimes.length; i++) {
      final String timeLabel = medication.reminderTimes[i];
      final (hour, minute) = _parseHHmm(timeLabel);

      if (medication.endDate != null) {
        final DateTime firstDose = DateTime(
          medication.startDate.year,
          medication.startDate.month,
          medication.startDate.day,
          hour,
          minute,
        );
        for (int day = 0; day < dayCount; day++) {
          final DateTime doseDateTime = firstDose.add(Duration(days: day));
          if (doseDateTime.isBefore(now)) continue;

          await NotificationService().scheduleNotificationOnce(
            id: _medicationTimedDayId(id, i, day),
            title: 'Recordatorio de medicación: ${medication.name}',
            body: _timedBody(medication, timeLabel),
            scheduledDateTime: doseDateTime,
            payload: id,
          );
        }
      } else {
        final DateTime firstOccurrence = _firstOccurrenceOnOrAfterStart(
          medication.startDate,
          hour,
          minute,
          now,
        );
        await NotificationService().scheduleDailyRepeatingNotification(
          id: _medicationRepeatingId(id, i),
          title: 'Recordatorio de medicación: ${medication.name}',
          body: _timedBody(medication, timeLabel),
          firstOccurrence: firstOccurrence,
          payload: id,
        );
      }
    }
  }

  static int _vaccinationNextId(String vaccinationId) =>
      '${vaccinationId}_next'.hashCode;

  static Future<void> cancelVaccinationReminder(Vaccination vaccination) async {
    await NotificationService()
        .cancelNotification(_vaccinationNextId(vaccination.id));
  }

  static Future<void> scheduleVaccinationReminder(Vaccination vaccination) async {
    if (vaccination.nextDueDate == null) return;

    await NotificationService().scheduleNotificationOnce(
      id: _vaccinationNextId(vaccination.id),
      title: 'Próxima vacuna: ${vaccination.vaccineName}',
      body: 'Hoy corresponde la próxima dosis de ${vaccination.vaccineName}.',
      scheduledDateTime: _atReminderHour(vaccination.nextDueDate!),
      payload: vaccination.id,
    );
  }

  static int _dewormingNextId(String dewormingId) =>
      '${dewormingId}_next'.hashCode;

  static Future<void> cancelDewormingReminder(Deworming deworming) async {
    if (deworming.id == null) return;
    await NotificationService()
        .cancelNotification(_dewormingNextId(deworming.id!));
  }

  static Future<void> scheduleDewormingReminder(Deworming deworming) async {
    if (deworming.id == null || deworming.nextDate == null) return;

    await NotificationService().scheduleNotificationOnce(
      id: _dewormingNextId(deworming.id!),
      title: 'Próxima desparasitación: ${deworming.product}',
      body: 'Hoy corresponde la próxima desparasitación con ${deworming.product}.',
      scheduledDateTime: _atReminderHour(deworming.nextDate!),
      payload: deworming.id,
    );
  }

  /// Recorre todas las mascotas y vuelve a programar los recordatorios
  /// pendientes (citas, medicaciones activas, próximas vacunas y próximas
  /// desparasitaciones), reutilizando siempre el mismo id por registro.
  /// zonedSchedule reemplaza la alarma existente si el id ya estaba
  /// programado, así que llamar esto repetidamente es seguro y no duplica
  /// notificaciones. Pensado para ejecutarse al iniciar la app, ya que
  /// Android borra las alarmas exactas pendientes al reiniciar el dispositivo.
  static Future<void> rescheduleAllPending() async {
    final dbHelper = DatabaseHelper();
    final pets = await dbHelper.getPets();
    final now = DateTime.now();

    for (final pet in pets) {
      final List<Appointment> appointments =
          await dbHelper.getAppointmentsForPet(pet.id);
      for (final appointment in appointments) {
        if (appointment.isCompleted) continue;
        final DateTime notifyAt =
            appointment.dateTime.subtract(const Duration(days: 1));
        if (notifyAt.isBefore(now)) continue;

        await NotificationService().scheduleNotificationOnce(
          id: appointment.id.hashCode,
          title: 'Recordatorio de Cita: ${appointment.title}',
          body:
              'Tu cita es mañana a las ${DateFormat('HH:mm').format(appointment.dateTime)}.',
          scheduledDateTime: notifyAt,
          payload: appointment.id,
        );
      }

      final List<Medication> medications =
          await dbHelper.getMedicationsForPet(pet.id);
      for (final medication in medications) {
        final bool expired =
            medication.endDate != null && medication.endDate!.isBefore(now);
        if (expired) {
          // Limpieza defensiva: si este tratamiento alguna vez fue
          // indefinido (sin endDate) y quedó con alarmas repetibles
          // activas por sus horarios, se cancelan ahora que ya venció.
          if (medication.id != null && medication.reminderTimes.isNotEmpty) {
            for (int i = 0; i < medication.reminderTimes.length; i++) {
              await NotificationService().cancelNotification(
                  _medicationRepeatingId(medication.id!, i));
            }
          }
          continue;
        }
        await scheduleMedicationReminders(medication);
      }

      final List<Vaccination> vaccinations =
          await dbHelper.getVaccinationsForPet(pet.id);
      for (final vaccination in vaccinations) {
        if (vaccination.nextDueDate == null) continue;
        if (vaccination.nextDueDate!.isBefore(now)) continue;
        await scheduleVaccinationReminder(vaccination);
      }

      final List<Deworming> dewormings =
          await dbHelper.getDewormingsForPet(pet.id);
      for (final deworming in dewormings) {
        if (deworming.nextDate == null) continue;
        if (deworming.nextDate!.isBefore(now)) continue;
        await scheduleDewormingReminder(deworming);
      }
    }
  }
}
