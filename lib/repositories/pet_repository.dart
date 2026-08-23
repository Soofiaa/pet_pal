import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/services/reminder_scheduler.dart';

/// Capa entre las pantallas y [DatabaseHelper] para Pet.
///
/// getPets/insertPet/updatePet son pass-through puro, igual que
/// WeightRecordRepository: no disparan ningún efecto secundario.
class PetRepository {
  PetRepository(this._dbHelper);

  final DatabaseHelper _dbHelper;

  Future<List<Pet>> getPets() => _dbHelper.getPets();

  Future<void> insertPet(Pet pet) => _dbHelper.insertPet(pet);

  Future<void> updatePet(Pet pet) => _dbHelper.updatePet(pet);

  /// ⚠️ NO llamar a DatabaseHelper().deletePet directo desde una pantalla.
  /// A diferencia del resto de los métodos de esta clase, deletePet SÍ
  /// orquesta un efecto secundario: cancela todos los recordatorios
  /// pendientes de la mascota (medicación, vacunas, desparasitación,
  /// citas) vía ReminderScheduler.cancelAllRemindersForPet antes de borrar
  /// el registro. Saltear este método deja esos recordatorios sonando
  /// indefinidamente para una mascota que ya no existe — exactamente el
  /// bug que tenía home_screen.dart.
  Future<void> deletePet(String id) async {
    await ReminderScheduler.cancelAllRemindersForPet(id);
    await _dbHelper.deletePet(id);
  }
}
