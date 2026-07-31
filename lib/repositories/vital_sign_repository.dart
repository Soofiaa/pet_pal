import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/vital_sign_config.dart';
import 'package:pet_pal/models/vital_sign_record.dart';

/// Capa de acceso a datos para Signos Vitales. Es SOLO acceso a datos: no
/// evalúa si un valor está fuera de rango ni dispara ninguna alerta -eso
/// lo hace VitalSignRecordsNotifier, igual que MedicationRepository /
/// MedicationsNotifier con los recordatorios de medicación.
///
/// ⚠️ NO llames a insertVitalSignRecord directamente desde una pantalla:
/// guarda el registro pero no evalúa la alerta de rango anormal. Usa
/// VitalSignRecordsNotifier.addVitalSignRecord
/// (lib/providers/vital_sign_providers.dart).
class VitalSignRepository {
  VitalSignRepository(this._dbHelper);

  final DatabaseHelper _dbHelper;

  Future<List<VitalSignRecord>> getVitalSignRecordsForPet(
    String petId, {
    VitalSignType? type,
  }) async {
    final records = await _dbHelper.getVitalSignRecordsForPet(petId);
    if (type == null) return records;
    return records.where((r) => r.type == type).toList();
  }

  /// ⚠️ No llamar directo desde una pantalla — ver el comentario de la clase.
  /// Usa VitalSignRecordsNotifier.addVitalSignRecord, que también evalúa
  /// la alerta de rango anormal.
  Future<int> insertVitalSignRecord(VitalSignRecord record) {
    return _dbHelper.insertVitalSignRecord(record);
  }

  Future<void> updateVitalSignRecord(VitalSignRecord record) {
    return _dbHelper.updateVitalSignRecord(record);
  }

  Future<void> deleteVitalSignRecord(int id) {
    return _dbHelper.deleteVitalSignRecord(id);
  }
}
