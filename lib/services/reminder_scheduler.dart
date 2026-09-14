// reminder_scheduler.dart
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/appointment.dart';
import 'package:pet_pal/models/dashboard_event.dart';
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

  /// Nombre para mostrar en el título de la notificación. Si la mascota ya
  /// no existe (por ejemplo, se borró pero el recordatorio no se canceló a
  /// tiempo) o la búsqueda falla por cualquier otro motivo (ej. la base de
  /// datos no está disponible en ese momento), cae a un texto genérico en
  /// vez de romper el armado del mensaje y dejar todo el recordatorio sin
  /// programar.
  static Future<String> _petDisplayName(String petId) async {
    try {
      final pet = await DatabaseHelper().getPetById(petId);
      if (pet == null) {
        // Caso esperado (no es un error): la mascota ya no existe -por
        // ejemplo se borró pero el recordatorio no se canceló a tiempo-.
        debugPrint(
            'Mascota no encontrada (petId: $petId) al armar el título de '
            'la notificación; se usa el nombre genérico.');
        return 'tu mascota';
      }
      return pet.name;
    } catch (e) {
      // Caso inesperado: la búsqueda en sí falló (ej. la base de datos no
      // está disponible en ese momento), no que la mascota no exista.
      debugPrint(
          'Error al buscar el nombre de la mascota para la notificación '
          '(petId: $petId): $e');
      return 'tu mascota';
    }
  }

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
    final String petName = await _petDisplayName(medication.petId);

    if (medication.reminderTimes.isEmpty) {
      await NotificationService().scheduleMedicationForDays(
        baseId: _medicationBaseId(id),
        title: 'Medicación para $petName: ${medication.name}',
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
            title: 'Medicación para $petName: ${medication.name}',
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
          title: 'Medicación para $petName: ${medication.name}',
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

    final String petName = await _petDisplayName(vaccination.petId);
    final DateTime notifyAt = _atReminderHour(
      vaccination.nextDueDate!.subtract(Duration(days: vaccination.reminderDaysAhead)),
    );

    await NotificationService().scheduleNotificationOnce(
      id: _vaccinationNextId(vaccination.id),
      title: 'Vacunación próxima para $petName: ${vaccination.vaccineName}',
      body: vaccination.reminderDaysAhead > 0
          ? 'Faltan ${vaccination.reminderDaysAhead} días para la próxima dosis de ${vaccination.vaccineName}.'
          : 'Hoy corresponde la próxima dosis de ${vaccination.vaccineName}.',
      scheduledDateTime: notifyAt,
      payload: vaccination.id,
    );
  }

  /// Recalcula, entre TODOS los registros de vacunación de una mascota,
  /// cuál es el ganador de cada grupo (mismo [Vaccination.vaccineName],
  /// mismo criterio que ya usa vaccinations_screen.dart vía
  /// [DashboardEvent.idsOfMostRecentApplicationPerName]), y deja el
  /// recordatorio programado solo para esos ganadores: cualquier otro
  /// registro del mismo grupo se cancela explícitamente. No cambia
  /// [scheduleVaccinationReminder]/[cancelVaccinationReminder] -siguen
  /// operando sobre un único registro, sin conocer el concepto de
  /// grupo-; esta función es la capa de arriba que decide a cuál de ellas
  /// llamar para cada registro.
  ///
  /// La llaman tanto VaccinationsNotifier (en cada alta/edición/baja) como
  /// [rescheduleAllPending], para que ambos caminos terminen siempre en el
  /// mismo estado -nunca más de un push activo por vacuna distinta- sin
  /// duplicar el criterio de "quién es el ganador" en dos lugares. Llamar
  /// esto repetidamente es seguro: reprogramar al ganador con el mismo id
  /// de siempre no duplica nada (zonedSchedule reemplaza), y cancelar a
  /// alguien sin recordatorio activo tampoco falla.
  static Future<void> reconcileVaccinationReminders(
    List<Vaccination> allVaccinationsForPet,
  ) async {
    final Set<dynamic> winnerIds = DashboardEvent.idsOfMostRecentApplicationPerName(
      Vaccination.getEventsFromList(allVaccinationsForPet),
      'vaccination',
    );

    for (final vaccination in allVaccinationsForPet) {
      if (winnerIds.contains(vaccination.id)) {
        await scheduleVaccinationReminder(vaccination);
      } else {
        await cancelVaccinationReminder(vaccination);
      }
    }
  }

  static int _dewormingNextId(String dewormingId) =>
      '${dewormingId}_next'.hashCode;

  static Future<void> cancelDewormingReminder(Deworming deworming) async {
    if (deworming.id == null) return;
    await NotificationService()
        .cancelNotification(_dewormingNextId(deworming.id!));
  }

  static Future<void> scheduleDewormingReminder(Deworming deworming) async {
    final DateTime? effectiveNextDate = deworming.effectiveNextDate();
    if (deworming.id == null || effectiveNextDate == null) return;

    final String petName = await _petDisplayName(deworming.petId);
    final DateTime notifyAt = _atReminderHour(
      effectiveNextDate.subtract(Duration(days: deworming.reminderDaysAhead)),
    );

    await NotificationService().scheduleNotificationOnce(
      id: _dewormingNextId(deworming.id!),
      title: 'Desparasitación próxima para $petName: ${deworming.product}',
      body: deworming.reminderDaysAhead > 0
          ? 'Faltan ${deworming.reminderDaysAhead} días para la próxima desparasitación con ${deworming.product}.'
          : 'Hoy corresponde la próxima desparasitación con ${deworming.product}.',
      scheduledDateTime: notifyAt,
      payload: deworming.id,
    );
  }

  /// Igual que [reconcileVaccinationReminders], pero para desparasitación:
  /// el criterio de "ganador" no es por producto sino por cobertura
  /// (interna/externa/ambas) según [Deworming.idsWithVisibleNextDose] -el
  /// mismo que ya usa deworming_screen.dart-, evaluado sobre TODO el
  /// historial de la mascota: un registro "ambas" puede resetear la
  /// cobertura de un producto completamente distinto, así que no alcanza
  /// con mirar solo el registro recién tocado.
  static Future<void> reconcileDewormingReminders(
    List<Deworming> allDewormingsForPet,
  ) async {
    final Set<String> winnerIds = Deworming.idsWithVisibleNextDose(allDewormingsForPet);

    for (final deworming in allDewormingsForPet) {
      final bool isWinner = deworming.id != null && winnerIds.contains(deworming.id);
      if (isWinner) {
        await scheduleDewormingReminder(deworming);
      } else {
        await cancelDewormingReminder(deworming);
      }
    }
  }

  static int _appointmentReminderId(String appointmentId) =>
      appointmentId.hashCode;

  /// Cancela el recordatorio de una cita (con la anticipación que sea que
  /// tuviera configurada, ver [Appointment.reminderDaysBefore]). Nunca falla
  /// si no había nada agendado con ese id -mismo comportamiento no-op seguro
  /// que el resto de los cancel* de esta clase-.
  static Future<void> cancelAppointmentReminder(Appointment appointment) async {
    await NotificationService()
        .cancelNotification(_appointmentReminderId(appointment.id));
  }

  /// Agenda el recordatorio de la cita, con la anticipación elegida por el
  /// usuario ([Appointment.reminderDaysBefore]; por defecto 1, "un día
  /// antes"). No agenda nada si la cita ya está marcada como completada,
  /// incluso si su fecha quedara en el futuro por algún motivo -antes de
  /// esta migración, add_edit_appointment_screen.dart no chequeaba esto y
  /// rescheduleAllPending sí, una inconsistencia entre las dos
  /// implementaciones duplicadas-.
  ///
  /// No hace falta chequear acá si el horario resultante ya pasó:
  /// NotificationService.scheduleNotificationOnce ya se niega a agendar en
  /// el pasado, con el mismo criterio (`isBefore(now)`) que se adopta como
  /// canónico acá.
  static Future<void> scheduleAppointmentReminder(Appointment appointment) async {
    if (appointment.isCompleted) return;

    final String petName = await _petDisplayName(appointment.petId);
    final int daysBefore = appointment.reminderDaysBefore;
    final DateTime notifyAt =
        appointment.dateTime.subtract(Duration(days: daysBefore));

    final String whenLabel = daysBefore == 0
        ? 'hoy'
        : daysBefore == 1
            ? 'mañana'
            : 'en $daysBefore días';

    await NotificationService().scheduleNotificationOnce(
      id: _appointmentReminderId(appointment.id),
      title: 'Cita próxima para $petName: ${appointment.title}',
      body:
          'Tu cita es $whenLabel a las ${DateFormat('HH:mm').format(appointment.dateTime)}.',
      scheduledDateTime: notifyAt,
      payload: appointment.id,
    );
  }

  static Future<void> cancelAllRemindersForPet(String petId) async {
    final dbHelper = DatabaseHelper();
    
    final vaccinations = await dbHelper.getVaccinationsForPet(petId);
    for (final v in vaccinations) {
      await cancelVaccinationReminder(v);
    }

    final dewormings = await dbHelper.getDewormingsForPet(petId);
    for (final d in dewormings) {
      await cancelDewormingReminder(d);
    }

    final medications = await dbHelper.getMedicationsForPet(petId);
    for (final m in medications) {
      await cancelMedicationReminders(m);
    }

    final appointments = await dbHelper.getAppointmentsForPet(petId);
    for (final a in appointments) {
      await cancelAppointmentReminder(a);
    }
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
        await scheduleAppointmentReminder(appointment);
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

      // reconcileVaccinationReminders/reconcileDewormingReminders ya
      // deciden, registro por registro, si corresponde programar (ganador
      // del grupo) o cancelar (perdedor) -incluyendo el filtro de fecha
      // pasada, que queda a cargo de scheduleVaccinationReminder/
      // scheduleDewormingReminder vía NotificationService.scheduleNotificationOnce
      // (ya se niega a agendar en el pasado). Esta es también la limpieza
      // que hace "salir gratis" la corrección de duplicados ya programados
      // en dispositivos con la versión vieja de la app: al arrancar,
      // cualquier recordatorio de un registro que dejó de ser ganador se
      // cancela acá, sin necesitar una migración aparte.
      final List<Vaccination> vaccinations =
          await dbHelper.getVaccinationsForPet(pet.id);
      await reconcileVaccinationReminders(vaccinations);

      final List<Deworming> dewormings =
          await dbHelper.getDewormingsForPet(pet.id);
      await reconcileDewormingReminders(dewormings);
    }
  }
}
