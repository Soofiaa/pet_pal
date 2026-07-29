import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/medication.dart';

/// Capa de acceso a datos para Medicación. Es SOLO acceso a datos:
/// a diferencia de MedicationsNotifier, NO programa ni cancela
/// recordatorios (ninguna de las tres ramas de ReminderScheduler:
/// legado sin reminderTimes, hash horario×día con endDate, o repetible
/// sin endDate).
///
/// ⚠️ NO llames a insertMedication/updateMedication/deleteMedication
/// directamente desde una pantalla. Hacerlo guarda o borra el registro
/// pero deja el recordatorio desincronizado (sin programar al crear, sin
/// cancelar al editar o eliminar) — exactamente la clase de bug
/// silencioso que la suite de Fase 1 se armó para atrapar.
///
/// Toda mutación debe pasar por MedicationsNotifier
/// (lib/providers/medication_providers.dart), que orquesta datos +
/// recordatorio como una sola operación. En la Opción A que se descartó,
/// el repository era la única puerta de escritura y esto era
/// estructuralmente imposible de olvidar; en la Opción B elegida esa
/// garantía ya no la da el compilador — depende de que quien escriba
/// código nuevo respete esta convención.
class MedicationRepository {
  MedicationRepository(this._dbHelper);

  final DatabaseHelper _dbHelper;

  Future<List<Medication>> getMedicationsForPet(String petId) {
    return _dbHelper.getMedicationsForPet(petId);
  }

  /// ⚠️ No llamar directo desde una pantalla — ver el comentario de la clase.
  /// Usa MedicationsNotifier.addMedication, que también programa el recordatorio.
  Future<void> insertMedication(Medication medication) {
    return _dbHelper.insertMedication(medication);
  }

  /// ⚠️ No llamar directo desde una pantalla — ver el comentario de la clase.
  /// Usa MedicationsNotifier.updateMedication, que también cancela/reprograma
  /// el recordatorio.
  Future<void> updateMedication(Medication medication) {
    return _dbHelper.updateMedication(medication);
  }

  /// ⚠️ No llamar directo desde una pantalla — ver el comentario de la clase.
  /// Usa MedicationsNotifier.deleteMedication, que también cancela el recordatorio.
  Future<void> deleteMedication(String id) {
    return _dbHelper.deleteMedication(id);
  }
}
