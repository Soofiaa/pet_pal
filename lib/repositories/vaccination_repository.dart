import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/vaccination.dart';

/// Capa de acceso a datos para Vacunas. Es SOLO acceso a datos: a
/// diferencia de VaccinationsNotifier, NO programa ni cancela
/// recordatorios, y NO gestiona los archivos de foto (adhesivo/extra).
///
/// ⚠️ NO llames a insertVaccination/updateVaccination/deleteVaccination
/// directamente desde una pantalla. Hacerlo guarda o borra el registro
/// pero deja desincronizados tanto el recordatorio (sin programar al
/// crear, sin cancelar al editar o eliminar) como los archivos de foto
/// (el archivo reemplazado en una edición, o los archivos de un registro
/// eliminado, quedan huérfanos en petpal_files/vaccinations/) —
/// exactamente la clase de bug silencioso que la suite de Fase 1 se armó
/// para atrapar.
///
/// Toda mutación debe pasar por VaccinationsNotifier
/// (lib/providers/vaccination_providers.dart), que orquesta datos +
/// recordatorio + archivos como una sola operación.
class VaccinationRepository {
  VaccinationRepository(this._dbHelper);

  final DatabaseHelper _dbHelper;

  Future<List<Vaccination>> getVaccinationsForPet(String petId) {
    return _dbHelper.getVaccinationsForPet(petId);
  }

  /// ⚠️ No llamar directo desde una pantalla — ver el comentario de la clase.
  /// Usa VaccinationsNotifier.addVaccination, que también programa el
  /// recordatorio.
  Future<void> insertVaccination(Vaccination vaccination) {
    return _dbHelper.insertVaccination(vaccination);
  }

  /// ⚠️ No llamar directo desde una pantalla — ver el comentario de la clase.
  /// Usa VaccinationsNotifier.updateVaccination, que también cancela/
  /// reprograma el recordatorio y limpia la foto reemplazada.
  Future<void> updateVaccination(Vaccination vaccination) {
    return _dbHelper.updateVaccination(vaccination);
  }

  /// ⚠️ No llamar directo desde una pantalla — ver el comentario de la clase.
  /// Usa VaccinationsNotifier.deleteVaccination, que también cancela el
  /// recordatorio y borra las fotos.
  Future<void> deleteVaccination(String id) {
    return _dbHelper.deleteVaccination(id);
  }
}
