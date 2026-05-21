import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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

      for (final pet in pets) {
        final notes = await _dbHelper.getNotesForPet(pet.id);
        final weightRecords = await _dbHelper.getWeightRecordsForPet(pet.id);
        final appointments = await _dbHelper.getAppointmentsForPet(pet.id);
        final vaccinations = await _dbHelper.getVaccinationsForPet(pet.id);
        final foodAllergies = await _dbHelper.getFoodAllergiesForPet(pet.id);
        final medications = await _dbHelper.getMedicationsForPet(pet.id);
        final dewormings = await _dbHelper.getDewormingsForPet(pet.id);

        petsJson.add({
          'id': pet.id,
          'name': pet.name,
          'species': pet.species,
          'breed': pet.breed,
          'dob': pet.dob.toIso8601String(),
          'color': pet.color,
          'imageUrl': pet.imageUrl,
          'notes': notes.map((n) => n.toJson()).toList(),
          'weightRecords': weightRecords.map((w) => w.toJson()).toList(),
          'appointments': appointments.map((a) => a.toJson()).toList(),
          'vaccinations': vaccinations.map((v) => v.toJson()).toList(),
          'foodAllergies': foodAllergies.map((f) => f.toJson()).toList(),
          'medications': medications.map((m) => m.toJson()).toList(),
          'dewormings': dewormings.map((d) => d.toJson()).toList(),
        });
      }

      final Map<String, dynamic> allData = {
        'version': 2,
        'format': 'petpal_full_zip_backup',
        'timestamp': DateTime.now().toIso8601String(),
        'pets': petsJson,
      };

      final archive = Archive();
      final Map<String, String> filePathMap = {};

      final Map<String, dynamic> dataWithRelativePaths =
          await _replaceLocalFilesWithBackupPaths(
        allData,
        archive,
        filePathMap,
      );

      final String jsonString = const JsonEncoder.withIndent('  ')
          .convert(dataWithRelativePaths);

      final Uint8List jsonBytes = Uint8List.fromList(utf8.encode(jsonString));

      archive.addFile(
        ArchiveFile(
          'backup.json',
          jsonBytes.length,
          jsonBytes,
        ),
      );

      final Uint8List zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

      final Directory tempDir = await getTemporaryDirectory();
      final String fileName =
          'pet_pal_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.zip';

      final File zipFile = File(p.join(tempDir.path, fileName));
      await zipFile.writeAsBytes(zipBytes);

      await Share.shareXFiles(
        [XFile(zipFile.path)],
        text: 'Copia de seguridad completa de PetPal',
      );

      return 'Copia de seguridad completa exportada con éxito.';
    } catch (e) {
      return 'Error al exportar datos: $e';
    }
  }

  Future<String> importAllData() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.single.path == null) {
        return 'Importación cancelada.';
      }

      final File zipFile = File(result.files.single.path!);
      final Uint8List zipBytes = await zipFile.readAsBytes();

      final Archive archive = ZipDecoder().decodeBytes(zipBytes);

      final ArchiveFile? backupJsonFile = archive.files
          .where((file) => file.name == 'backup.json')
          .cast<ArchiveFile?>()
          .firstOrNull;

      if (backupJsonFile == null) {
        return 'El respaldo no contiene backup.json.';
      }

      final String jsonString = utf8.decode(backupJsonFile.content as List<int>);
      final Map<String, dynamic> allData = jsonDecode(jsonString);

      if (allData['pets'] == null || allData['pets'] is! List) {
        return 'Formato de archivo de copia de seguridad inválido.';
      }

      final Map<String, dynamic> restoredData =
          await _restoreBackupFilesToLocalPaths(allData, archive);

      await _dbHelper.deleteAllData();

      final List<dynamic> petsJson = restoredData['pets'];

      for (final petData in petsJson) {
        final Pet pet = Pet.fromJson(petData);
        final String newPetId = pet.id;

        await _dbHelper.insertPet(pet);

        if (petData['notes'] is List) {
          for (final noteData in petData['notes']) {
            final Note note = Note.fromJson(noteData);
            await _dbHelper.insertNote(note.copyWith(petId: newPetId));
          }
        }

        if (petData['weightRecords'] is List) {
          for (final data in petData['weightRecords']) {
            final WeightRecord record = WeightRecord.fromJson(data);
            await _dbHelper.insertWeightRecord(record.copyWith(petId: newPetId));
          }
        }

        if (petData['appointments'] is List) {
          for (final data in petData['appointments']) {
            final Appointment appointment = Appointment.fromJson(data);
            await _dbHelper.insertAppointment(
              appointment.copyWith(petId: newPetId),
            );
          }
        }

        if (petData['vaccinations'] is List) {
          for (final data in petData['vaccinations']) {
            final Vaccination vaccination = Vaccination.fromJson(data);
            await _dbHelper.insertVaccination(
              vaccination.copyWith(petId: newPetId),
            );
          }
        }

        if (petData['foodAllergies'] is List) {
          for (final data in petData['foodAllergies']) {
            final FoodAllergy allergy = FoodAllergy.fromJson(data);
            await _dbHelper.insertFoodAllergy(
              allergy.copyWith(petId: newPetId),
            );
          }
        }

        if (petData['medications'] is List) {
          for (final data in petData['medications']) {
            final Medication medication = Medication.fromJson(data);
            await _dbHelper.insertMedication(
              medication.copyWith(petId: newPetId),
            );
          }
        }

        if (petData['dewormings'] is List) {
          for (final data in petData['dewormings']) {
            final Deworming deworming = Deworming.fromJson(data);
            await _dbHelper.insertDeworming(
              deworming.copyWith(petId: newPetId),
            );
          }
        }
      }

      return 'Datos e imágenes importados con éxito.';
    } catch (e) {
      return 'Error al importar datos: $e';
    }
  }

  Future<Map<String, dynamic>> _replaceLocalFilesWithBackupPaths(
    Map<String, dynamic> data,
    Archive archive,
    Map<String, String> filePathMap,
  ) async {
    final dynamic processed = await _processValueForExport(
      data,
      archive,
      filePathMap,
    );

    return Map<String, dynamic>.from(processed);
  }

  Future<dynamic> _processValueForExport(
    dynamic value,
    Archive archive,
    Map<String, String> filePathMap,
  ) async {
    if (value is Map) {
      final Map<String, dynamic> result = {};

      for (final entry in value.entries) {
        result[entry.key.toString()] = await _processValueForExport(
          entry.value,
          archive,
          filePathMap,
        );
      }

      return result;
    }

    if (value is List) {
      final List<dynamic> result = [];

      for (final item in value) {
        result.add(await _processValueForExport(item, archive, filePathMap));
      }

      return result;
    }

    if (value is String && await _isExistingLocalFile(value)) {
      if (filePathMap.containsKey(value)) {
        return filePathMap[value];
      }

      final File file = File(value);
      final Uint8List fileBytes = await file.readAsBytes();

      final String extension = p.extension(file.path);
      final String safeName =
          '${DateTime.now().millisecondsSinceEpoch}_${filePathMap.length}$extension';

      final String backupPath = 'files/$safeName';

      archive.addFile(
        ArchiveFile(
          backupPath,
          fileBytes.length,
          fileBytes,
        ),
      );

      filePathMap[value] = backupPath;

      return backupPath;
    }

    return value;
  }

  Future<Map<String, dynamic>> _restoreBackupFilesToLocalPaths(
    Map<String, dynamic> data,
    Archive archive,
  ) async {
    final Directory documentsDir = await getApplicationDocumentsDirectory();

    final Directory restoredFilesDir = Directory(
      p.join(documentsDir.path, 'petpal_restored_files'),
    );

    if (!await restoredFilesDir.exists()) {
      await restoredFilesDir.create(recursive: true);
    }

    final dynamic processed = await _processValueForImport(
      data,
      archive,
      restoredFilesDir,
    );

    return Map<String, dynamic>.from(processed);
  }

  Future<dynamic> _processValueForImport(
    dynamic value,
    Archive archive,
    Directory restoredFilesDir,
  ) async {
    if (value is Map) {
      final Map<String, dynamic> result = {};

      for (final entry in value.entries) {
        result[entry.key.toString()] = await _processValueForImport(
          entry.value,
          archive,
          restoredFilesDir,
        );
      }

      return result;
    }

    if (value is List) {
      final List<dynamic> result = [];

      for (final item in value) {
        result.add(await _processValueForImport(item, archive, restoredFilesDir));
      }

      return result;
    }

    if (value is String && value.startsWith('files/')) {
      final ArchiveFile? backupFile = archive.files
          .where((file) => file.name == value)
          .cast<ArchiveFile?>()
          .firstOrNull;

      if (backupFile == null) {
        return value;
      }

      final String localPath = p.join(
        restoredFilesDir.path,
        p.basename(value),
      );

      final File localFile = File(localPath);
      await localFile.writeAsBytes(backupFile.content as List<int>);

      return localPath;
    }

    return value;
  }

  Future<bool> _isExistingLocalFile(String value) async {
    if (value.trim().isEmpty) return false;

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return false;
    }

    final File file = File(value);

    if (!await file.exists()) return false;

    final String extension = p.extension(value).toLowerCase();

    const allowedExtensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
      '.heic',
      '.pdf',
    ];

    return allowedExtensions.contains(extension);
  }
}

extension FirstOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull {
    if (isEmpty) return null;
    return first;
  }
}