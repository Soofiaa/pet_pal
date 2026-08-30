import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/food_record.dart';

/// Capa de acceso a datos para Historial de Alimentos (Opción B, misma
/// forma que FoodAllergyRepository/WeightRecordRepository). Es SOLO acceso
/// a datos: sin archivos, sin ReminderScheduler.
///
/// ⚠️ NO llames a insertFoodRecord/updateFoodRecord/deleteFoodRecord
/// directamente desde una pantalla. Usa FoodRecordsNotifier
/// (lib/providers/food_record_providers.dart), que es la única puerta de
/// escritura real y refresca el estado después de cada mutación.
class FoodRecordRepository {
  FoodRecordRepository(this._dbHelper);

  final DatabaseHelper _dbHelper;

  Future<List<FoodRecord>> getFoodRecordsForPet(String petId) {
    return _dbHelper.getFoodRecordsForPet(petId);
  }

  /// ⚠️ No llamar directo desde una pantalla — ver el comentario de la clase.
  Future<int> insertFoodRecord(FoodRecord foodRecord) {
    return _dbHelper.insertFoodRecord(foodRecord);
  }

  /// ⚠️ No llamar directo desde una pantalla — ver el comentario de la clase.
  Future<void> updateFoodRecord(FoodRecord foodRecord) {
    return _dbHelper.updateFoodRecord(foodRecord);
  }

  /// ⚠️ No llamar directo desde una pantalla — ver el comentario de la clase.
  Future<void> deleteFoodRecord(int id) {
    return _dbHelper.deleteFoodRecord(id);
  }
}
