import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/note.dart';
import 'package:pet_pal/models/weight_record.dart';
import 'package:pet_pal/models/appointment.dart';
import 'package:pet_pal/models/vaccination.dart';
import 'package:pet_pal/models/food_allergy.dart';
import 'package:pet_pal/models/medication.dart';
import 'package:pet_pal/models/deworming.dart';

class DataBackupService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<String> exportAllData() async {
    try {
      final List<Pet> pets = await _dbHelper.getPets();
      final List<Map<String, dynamic>> petsJson = [];

      for (var pet in pets) {
        final List<Note> notes = await _dbHelper.getNotesForPet(pet.id);
        final List<WeightRecord> weightRecords = await _dbHelper.getWeightRecordsForPet(pet.id);
        final List<Appointment> appointments = await _dbHelper.getAppointmentsForPet(pet.id);
        final List<Vaccination> vaccinations = await _dbHelper.getVaccinationsForPet(pet.id);
        final List<FoodAllergy> foodAllergies = await _dbHelper.getFoodAllergiesForPet(pet.id);
        final List<Medication> medications = await _dbHelper.getMedicationsForPet(pet.id);
        final List<Deworming> dewormings = await _dbHelper.getDewormingsForPet(pet.id);

        petsJson.add({
          'id': pet.id,
          'name': pet.name,
          'species': pet.species,
          'breed': pet.breed,
          'dob': pet.dob.toIso8601String(),
          'color': pet.color,
          'imageUrl': pet.imageUrl,
          'notes': notes.map((n) => n.toJson()).toList(),
          'weightRecords': weightRecords.map((wr) => wr.toJson()).toList(),
          'appointments': appointments.map((a) => a.toJson()).toList(),
          'vaccinations': vaccinations.map((v) => v.toJson()).toList(),
          'foodAllergies': foodAllergies.map((fa) => fa.toJson()).toList(),
          'medications': medications.map((m) => m.toJson()).toList(),
          'dewormings': dewormings.map((d) => d.toJson()).toList(),
        });
      }

      final Map<String, dynamic> allData = {
        'timestamp': DateTime.now().toIso8601String(),
        'version': 1,
        'pets': petsJson,
      };

      final String jsonString = jsonEncode(allData);
      final Uint8List jsonBytes = Uint8List.fromList(utf8.encode(jsonString));
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = 'pet_pal_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
      final File file = File(p.join(tempDir.path, fileName));
      await file.writeAsBytes(jsonBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Copia de seguridad de PetPal');

      return 'Copia de seguridad exportada con éxito a: ${file.path}';
    } catch (e) {
      return 'Error al exportar datos: $e';
    }
  }

  Future<String> importAllData() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        return 'Importación cancelada.';
      }

      final File file = File(result.files.single.path!);
      final String jsonString = await file.readAsString();
      final Map<String, dynamic> allData = jsonDecode(jsonString);

      if (allData['pets'] == null || allData['pets'] is! List) {
        return 'Formato de archivo de copia de seguridad inválido.';
      }

      // Borramos todos los datos existentes para evitar duplicados
      await _dbHelper.deleteAllData();

      final List<dynamic> petsJson = allData['pets'];
      for (var petData in petsJson) {
        final Pet pet = Pet.fromJson(petData);
        // El ID de la mascota ya viene del archivo de respaldo
        final String newPetId = pet.id;
        await _dbHelper.insertPet(pet);

        if (petData['notes'] != null && petData['notes'] is List) {
          for (var noteData in petData['notes']) {
            final Note note = Note.fromJson(noteData);
            // Asignamos el nuevo ID de la mascota al registro de nota
            await _dbHelper.insertNote(note.copyWith(petId: newPetId));
          }
        }

        if (petData['weightRecords'] != null && petData['weightRecords'] is List) {
          for (var weightRecordData in petData['weightRecords']) {
            final WeightRecord weightRecord = WeightRecord.fromJson(weightRecordData);
            await _dbHelper.insertWeightRecord(weightRecord.copyWith(petId: newPetId));
          }
        }

        if (petData['appointments'] != null && petData['appointments'] is List) {
          for (var appointmentData in petData['appointments']) {
            final Appointment appointment = Appointment.fromJson(appointmentData);
            await _dbHelper.insertAppointment(appointment.copyWith(petId: newPetId));
          }
        }

        if (petData['vaccinations'] != null && petData['vaccinations'] is List) {
          for (var vaccinationData in petData['vaccinations']) {
            final Vaccination vaccination = Vaccination.fromJson(vaccinationData);
            await _dbHelper.insertVaccination(vaccination.copyWith(petId: newPetId));
          }
        }

        if (petData['foodAllergies'] != null && petData['foodAllergies'] is List) {
          for (var foodAllergyData in petData['foodAllergies']) {
            final FoodAllergy foodAllergy = FoodAllergy.fromJson(foodAllergyData);
            await _dbHelper.insertFoodAllergy(foodAllergy.copyWith(petId: newPetId));
          }
        }

        if (petData['medications'] != null && petData['medications'] is List) {
          for (var medicationData in petData['medications']) {
            final Medication medication = Medication.fromJson(medicationData);
            await _dbHelper.insertMedication(medication.copyWith(petId: newPetId));
          }
        }

        if (petData['dewormings'] != null && petData['dewormings'] is List) {
          for (var dewormingData in petData['dewormings']) {
            final Deworming deworming = Deworming.fromJson(dewormingData);
            await _dbHelper.insertDeworming(deworming.copyWith(petId: newPetId));
          }
        }
      }

      return 'Datos importados con éxito.';
    } catch (e) {
      return 'Error al importar datos: $e';
    }
  }
}