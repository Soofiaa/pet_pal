import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/weight_record.dart';

/// Capa entre las pantallas de Peso y [DatabaseHelper].
///
/// Hoy es casi un pass-through directo: el punto no es agregar lógica
/// nueva ahora mismo, sino que las pantallas dependan de esta interfaz en
/// vez de instanciar DatabaseHelper directamente, para poder sustituir o
/// extender el almacenamiento (o inyectar un fake en tests) sin tocar la UI.
class WeightRecordRepository {
  WeightRecordRepository(this._dbHelper);

  final DatabaseHelper _dbHelper;

  Future<List<WeightRecord>> getWeightRecordsForPet(String petId) {
    return _dbHelper.getWeightRecordsForPet(petId);
  }

  Future<int> insertWeightRecord(WeightRecord record) {
    return _dbHelper.insertWeightRecord(record);
  }

  Future<void> updateWeightRecord(WeightRecord record) {
    return _dbHelper.updateWeightRecord(record);
  }

  Future<void> deleteWeightRecord(int id) {
    return _dbHelper.deleteWeightRecord(id);
  }
}
