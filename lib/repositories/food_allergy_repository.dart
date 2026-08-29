import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/food_allergy.dart';

/// Capa de acceso a datos para Alergias Alimentarias (Opción B, misma
/// forma que DewormingRepository/DocumentRepository/NoteRepository/
/// AppointmentRepository). Es SOLO acceso a datos: sin archivos, sin
/// ReminderScheduler — el caso más simple de las cuatro migraciones,
/// análogo a WeightRecordRepository.
///
/// ⚠️ NO llames a insertFoodAllergy/updateFoodAllergy/deleteFoodAllergy
/// directamente desde una pantalla. Usa FoodAllergiesNotifier
/// (lib/providers/food_allergy_providers.dart), que es la única puerta de
/// escritura real y refresca el estado después de cada mutación.
///
/// El mapeo del campo Dart `food` a la columna real `allergies` de la
/// tabla vive enteramente en FoodAllergy.toJson/fromJson -corrección de
/// un crash de producción (ningún guardado había funcionado nunca, en
/// ninguna versión de la app)-. Este repository no reconstruye el mapa a
/// mano en ningún punto, solo pasa el objeto FoodAllergy a DatabaseHelper,
/// así que no puede reintroducir ese desajuste.
class FoodAllergyRepository {
  FoodAllergyRepository(this._dbHelper);

  final DatabaseHelper _dbHelper;

  Future<List<FoodAllergy>> getFoodAllergiesForPet(String petId) {
    return _dbHelper.getFoodAllergiesForPet(petId);
  }

  /// ⚠️ No llamar directo desde una pantalla — ver el comentario de la clase.
  Future<int> insertFoodAllergy(FoodAllergy foodAllergy) {
    return _dbHelper.insertFoodAllergy(foodAllergy);
  }

  /// ⚠️ No llamar directo desde una pantalla — ver el comentario de la clase.
  Future<void> updateFoodAllergy(FoodAllergy foodAllergy) {
    return _dbHelper.updateFoodAllergy(foodAllergy);
  }

  /// ⚠️ No llamar directo desde una pantalla — ver el comentario de la clase.
  Future<void> deleteFoodAllergy(int id) {
    return _dbHelper.deleteFoodAllergy(id);
  }
}
