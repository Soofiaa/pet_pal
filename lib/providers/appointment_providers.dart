import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/appointment.dart';
import 'package:pet_pal/providers/database_providers.dart';
import 'package:pet_pal/repositories/appointment_repository.dart';
import 'package:pet_pal/services/reminder_scheduler.dart';

final appointmentRepositoryProvider = Provider<AppointmentRepository>((ref) {
  return AppointmentRepository(ref.watch(databaseHelperProvider));
});

/// Reemplaza los antiguos campos _appointments/_isLoading manejados a mano
/// en appointments_screen.dart. Es la única puerta de escritura real para
/// Citas (ver el comentario de AppointmentRepository): además de los
/// datos, orquesta ReminderScheduler.scheduleAppointmentReminder/
/// cancelAppointmentReminder, ya que el recordatorio es parte de la misma
/// operación de guardar/eliminar -antes de esta migración, esa lógica
/// vivía duplicada e inconsistente en tres lugares distintos-.
final appointmentsProvider = AsyncNotifierProvider.family<AppointmentsNotifier,
    List<Appointment>, String>(AppointmentsNotifier.new);

class AppointmentsNotifier extends FamilyAsyncNotifier<List<Appointment>, String> {
  @override
  Future<List<Appointment>> build(String petId) async {
    final repository = ref.watch(appointmentRepositoryProvider);

    // Mismo comportamiento que _loadAppointments() tenía en
    // appointments_screen.dart antes de esta migración: marca como
    // completadas las citas vencidas y no completadas todavía, cada vez
    // que se (re)carga la lista. Una sola lectura: los objetos actualizados
    // se arman en memoria (copyWith) en el mismo lugar donde se persisten,
    // en vez de volver a golpear la base de datos con una segunda lectura
    // completa después del loop de escritura.
    final appointments = await repository.getAppointmentsForPet(petId);
    final DateTime now = DateTime.now();
    final List<Appointment> result = [];
    for (final appointment in appointments) {
      if (!appointment.isCompleted && appointment.dateTime.isBefore(now)) {
        final completed = appointment.copyWith(isCompleted: true);
        await repository.updateAppointment(completed);
        result.add(completed);
      } else {
        result.add(appointment);
      }
    }

    result.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return result;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build(arg));
  }

  Future<void> addAppointment(Appointment appointment) async {
    await ReminderScheduler.scheduleAppointmentReminder(appointment);
    await ref.read(appointmentRepositoryProvider).insertAppointment(appointment);
    await refresh();
  }

  /// Actualiza una cita existente. Mismo patrón old+new que
  /// DewormingsNotifier.updateDeworming: cancela el recordatorio de
  /// [oldAppointment] antes de agendar el de [updatedAppointment]. El id de
  /// notificación nunca cambia entre ediciones (siempre
  /// `appointment.id.hashCode`), así que esto no es para evitar una
  /// colisión de ids -zonedSchedule ya sobreescribiría al mismo id- sino
  /// para poder "apagar" el recordatorio cuando la versión editada ya no
  /// amerita uno (se movió al pasado, o quedó marcada como completada):
  /// sin el cancel explícito, simplemente no volver a llamar a schedule
  /// dejaría sonando el recordatorio viejo.
  Future<void> updateAppointment(
    Appointment oldAppointment,
    Appointment updatedAppointment,
  ) async {
    await ReminderScheduler.cancelAppointmentReminder(oldAppointment);
    await ReminderScheduler.scheduleAppointmentReminder(updatedAppointment);
    await ref.read(appointmentRepositoryProvider).updateAppointment(updatedAppointment);
    await refresh();
  }

  /// Elimina una cita y cancela su recordatorio. Mismo orden que usaba
  /// appointments_screen.dart: cancela antes de borrar.
  Future<void> deleteAppointment(Appointment appointment) async {
    await ReminderScheduler.cancelAppointmentReminder(appointment);
    await ref.read(appointmentRepositoryProvider).deleteAppointment(appointment.id);
    await refresh();
  }
}
