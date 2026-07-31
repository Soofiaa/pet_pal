import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/pet.dart';

/// Capa entre las pantallas y [DatabaseHelper] para Pet, mismo patrón
/// pass-through que WeightRecordRepository. Pet no dispara notificaciones,
/// así que no aplica la restricción "Opción B" de MedicationRepository.
class PetRepository {
  PetRepository(this._dbHelper);

  final DatabaseHelper _dbHelper;

  Future<List<Pet>> getPets() => _dbHelper.getPets();

  Future<void> insertPet(Pet pet) => _dbHelper.insertPet(pet);

  Future<void> updatePet(Pet pet) => _dbHelper.updatePet(pet);

  Future<void> deletePet(String id) => _dbHelper.deletePet(id);
}
