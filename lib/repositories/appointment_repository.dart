import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/appointment.dart';

/// Capa de acceso a datos para Citas (Opción B, misma forma que
/// DewormingRepository/DocumentRepository/NoteRepository: es SOLO acceso a
/// datos, no orquesta el recordatorio.
///
/// ⚠️ NO llames a insertAppointment/updateAppointment/deleteAppointment
/// directamente desde una pantalla. Hacerlo guarda o borra el registro pero
/// deja el recordatorio desincronizado (una cita nueva sin notificación
/// programada, o una cita borrada con su notificación todavía sonando) —
/// exactamente la clase de bug que tenían duplicada
/// add_edit_appointment_screen.dart y appointments_screen.dart antes de
/// esta migración, cada una calculando el id de notificación por su cuenta.
///
/// Toda mutación debe pasar por AppointmentsNotifier
/// (lib/providers/appointment_providers.dart), que orquesta datos +
/// recordatorio (vía ReminderScheduler) como una sola operación.
class AppointmentRepository {
  AppointmentRepository(this._dbHelper);

  final DatabaseHelper _dbHelper;

  Future<List<Appointment>> getAppointmentsForPet(String petId) {
    return _dbHelper.getAppointmentsForPet(petId);
  }

  /// ⚠️ No llamar directo desde una pantalla — ver el comentario de la clase.
  /// Usa AppointmentsNotifier.addAppointment, que también agenda el
  /// recordatorio.
  Future<void> insertAppointment(Appointment appointment) {
    return _dbHelper.insertAppointment(appointment);
  }

  /// ⚠️ No llamar directo desde una pantalla — ver el comentario de la clase.
  /// Usa AppointmentsNotifier.updateAppointment, que también cancela el
  /// recordatorio viejo y agenda el nuevo.
  Future<void> updateAppointment(Appointment appointment) {
    return _dbHelper.updateAppointment(appointment);
  }

  /// ⚠️ No llamar directo desde una pantalla — ver el comentario de la clase.
  /// Usa AppointmentsNotifier.deleteAppointment, que también cancela el
  /// recordatorio.
  Future<void> deleteAppointment(String id) {
    return _dbHelper.deleteAppointment(id);
  }
}
