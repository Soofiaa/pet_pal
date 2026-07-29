import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/deworming.dart';

/// Capa de acceso a datos para Desparasitación. Es SOLO acceso a datos:
/// a diferencia de DewormingsNotifier, NO programa ni cancela
/// recordatorios.
///
/// ⚠️ NO llames a insertDeworming/updateDeworming/deleteDeworming
/// directamente desde una pantalla. Hacerlo guarda o borra el registro
/// pero deja el recordatorio desincronizado (sin programar al crear, sin
/// cancelar al editar o eliminar) — exactamente la clase de bug
/// silencioso que la suite de Fase 1 se armó para atrapar.
///
/// Toda mutación debe pasar por DewormingsNotifier
/// (lib/providers/deworming_providers.dart), que orquesta datos +
/// recordatorio como una sola operación. En la Opción A que se descartó,
/// el repository era la única puerta de escritura y esto era
/// estructuralmente imposible de olvidar; en la Opción B elegida esa
/// garantía ya no la da el compilador — depende de que quien escriba
/// código nuevo respete esta convención.
class DewormingRepository {
  DewormingRepository(this._dbHelper);

  final DatabaseHelper _dbHelper;

  Future<List<Deworming>> getDewormingsForPet(String petId) {
    return _dbHelper.getDewormingsForPet(petId);
  }

  /// ⚠️ No llamar directo desde una pantalla — ver el comentario de la clase.
  /// Usa DewormingsNotifier.addDeworming, que también programa el recordatorio.
  Future<void> insertDeworming(Deworming deworming) {
    return _dbHelper.insertDeworming(deworming);
  }

  /// ⚠️ No llamar directo desde una pantalla — ver el comentario de la clase.
  /// Usa DewormingsNotifier.updateDeworming, que también cancela/reprograma
  /// el recordatorio.
  Future<void> updateDeworming(Deworming deworming) {
    return _dbHelper.updateDeworming(deworming);
  }

  /// ⚠️ No llamar directo desde una pantalla — ver el comentario de la clase.
  /// Usa DewormingsNotifier.deleteDeworming, que también cancela el recordatorio.
  Future<void> deleteDeworming(String id) {
    return _dbHelper.deleteDeworming(id);
  }
}
