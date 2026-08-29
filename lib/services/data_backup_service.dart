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
import 'package:pet_pal/models/document.dart';
import 'package:pet_pal/models/vital_sign_record.dart';
import 'package:pet_pal/models/medication_intake.dart';
import 'package:pet_pal/models/pet_food_config.dart';
import 'package:pet_pal/models/deworming_product.dart';
import 'package:pet_pal/models/vaccination_product.dart';
import 'package:pet_pal/models/emergency_contact.dart';

/// Resumen de un backup ya descifrado y validado, previo a reemplazar los
/// datos actuales -para que la UI pueda mostrarle al usuario de qué
/// respaldo se trata antes de confirmar el paso destructivo.
class BackupRestorePreview {
  const BackupRestorePreview({
    required this.restoredData,
    required this.timestamp,
    required this.petCount,
    required this.petNames,
  });

  /// Datos ya procesados (con los paths de archivos adjuntos restaurados a
  /// disco), listos para pasar a [DataBackupService.applyRestoredBackup].
  final Map<String, dynamic> restoredData;

  /// Momento en que se generó el backup (campo `timestamp` de backup.json).
  /// `null` si el backup es de un formato anterior que no lo incluía.
  final DateTime? timestamp;

  final int petCount;

  /// Nombres de las mascotas incluidas en el backup, en el mismo orden que
  /// `restoredData['pets']` -para que la UI pueda mostrarle al usuario a
  /// quiénes va a restaurar antes del reemplazo destructivo, no solo cuántas.
  final List<String> petNames;
}

/// Resultado de [DataBackupService.loadBackupForRestore]: o bien [preview]
/// (éxito) o bien [error] (mensaje para mostrarle al usuario), nunca ambos.
class BackupLoadResult {
  const BackupLoadResult.success(this.preview) : error = null;

  const BackupLoadResult.failure(this.error) : preview = null;

  final BackupRestorePreview? preview;
  final String? error;
}

class DataBackupService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// [password] cifra el ZIP con AES (soportado nativamente por
  /// `archive` vía `ZipEncoder(password: ...)`) — desde que `documents`
  /// incluye archivos médicos reales, el backup ya no viaja en texto plano.
  Future<String> exportAllData(String password) async {
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
        final documents = await _dbHelper.getDocumentsForPet(pet.id);
        final vitalSigns = await _dbHelper.getVitalSignRecordsForPet(pet.id);
        final foodConfig = await _dbHelper.getFoodConfigForPet(pet.id);

        // ✅ NUEVO: Obtener todas las tomas registradas para esta mascota
        final List<MedicationIntake> intakes = [];
        for (final medication in medications) {
          final mIntakes = await _dbHelper.getIntakesForMedication(medication.id!);
          intakes.addAll(mIntakes);
        }

        petsJson.add({
          ...pet.toJson(),
          'notes': notes.map((n) => n.toJson()).toList(),
          'weightRecords': weightRecords.map((w) => w.toJson()).toList(),
          'appointments': appointments.map((a) => a.toJson()).toList(),
          'vaccinations': vaccinations.map((v) => v.toJson()).toList(),
          'foodAllergies': foodAllergies.map((f) => f.toJson()).toList(),
          'medications': medications.map((m) => m.toJson()).toList(),
          'dewormings': dewormings.map((d) => d.toJson()).toList(),
          'documents': documents.map((doc) => doc.toJson()).toList(),
          'vitalSigns': vitalSigns.map((v) => v.toJson()).toList(),
          'foodConfig': foodConfig?.toJson(),
          'medicationIntakes': intakes.map((i) => i.toJson()).toList(),
        });
      }

      final dewormingProducts = await _dbHelper.getDewormingProducts();
      final vaccinationProducts = await _dbHelper.getVaccinationProducts();
      final emergencyContacts = await _dbHelper.getEmergencyContacts();

      final Map<String, dynamic> allData = {
        'version': 3,
        'format': 'petpal_full_zip_backup_v3',
        'timestamp': DateTime.now().toIso8601String(),
        'appVersion': '1.0.0',
        'pets': petsJson,
        'dewormingProducts': dewormingProducts.map((p) => p.toJson()).toList(),
        'vaccinationProducts': vaccinationProducts.map((p) => p.toJson()).toList(),
        'emergencyContacts': emergencyContacts.map((c) => c.toJson()).toList(),
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

      final Uint8List zipBytes = Uint8List.fromList(
        ZipEncoder(password: password).encode(archive)!,
      );

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

  /// Restaura un backup de punta a punta sin mostrar una previsualización
  /// intermedia -combina [loadBackupForRestore] + [applyRestoredBackup].
  /// Usado por callers que no necesitan confirmar con el usuario antes del
  /// reemplazo (p. ej. tests); backup_settings_screen.dart usa las dos
  /// fases por separado para mostrar la fecha del respaldo antes de aplicar.
  Future<String> importAllData({required String password}) async {
    final BackupLoadResult loadResult = await loadBackupForRestore(password: password);
    if (loadResult.error != null) {
      return loadResult.error!;
    }
    return applyRestoredBackup(loadResult.preview!.restoredData);
  }

  /// Lee, descifra y valida el ZIP elegido por el usuario, y restaura sus
  /// archivos adjuntos a disco -pero sin tocar la base de datos todavía-.
  /// Separado de [applyRestoredBackup] para que la UI pueda mostrar de qué
  /// respaldo se trata (fecha, cantidad de mascotas) antes del paso
  /// destructivo real de reemplazar todos los datos actuales.
  Future<BackupLoadResult> loadBackupForRestore({required String password}) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.single.path == null) {
        return const BackupLoadResult.failure('Importación cancelada.');
      }

      final File zipFile = File(result.files.single.path!);
      final Uint8List zipBytes = await zipFile.readAsBytes();

      final Archive archive;
      try {
        // verify:true fuerza la validación HMAC (formato AE-2) en este
        // punto; sin esto, decodeBytes con una contraseña incorrecta no
        // lanza nada y devuelve un Archive "válido" cuyo contenido
        // descomprimido recién falla (o peor, produce basura) más
        // adelante en el pipeline de restauración.
        archive = ZipDecoder().decodeBytes(zipBytes, password: password, verify: true);
      } catch (e) {
        return const BackupLoadResult.failure(
          'No se pudo abrir el respaldo. Verifica que la contraseña sea correcta.',
        );
      }

      final ArchiveFile? backupJsonFile = archive.files
          .where((file) => file.name == 'backup.json')
          .cast<ArchiveFile?>()
          .firstOrNull;

      if (backupJsonFile == null) {
        return const BackupLoadResult.failure('El respaldo no contiene backup.json.');
      }

      final String jsonString = utf8.decode(backupJsonFile.content as List<int>);
      final Map<String, dynamic> allData = jsonDecode(jsonString);

      if (allData['pets'] == null || allData['pets'] is! List) {
        return const BackupLoadResult.failure('Formato de archivo de copia de seguridad inválido.');
      }

      final Map<String, dynamic> restoredData =
          await _restoreBackupFilesToLocalPaths(allData, archive);

      final rawTimestamp = allData['timestamp'];
      final DateTime? timestamp = rawTimestamp is String ? DateTime.tryParse(rawTimestamp) : null;

      final List<dynamic> restoredPets = restoredData['pets'] as List;
      final List<String> petNames = restoredPets
          .map((petData) => (petData as Map)['name'] as String? ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      return BackupLoadResult.success(
        BackupRestorePreview(
          restoredData: restoredData,
          timestamp: timestamp,
          petCount: restoredPets.length,
          petNames: petNames,
        ),
      );
    } catch (e) {
      return BackupLoadResult.failure('Error al leer el respaldo: $e');
    }
  }

  /// Reemplaza todos los datos actuales por los de [restoredData] -salida de
  /// [loadBackupForRestore]-. Paso destructivo e irreversible: la UI debe
  /// haber confirmado con el usuario antes de llamarlo.
  Future<String> applyRestoredBackup(Map<String, dynamic> restoredData) async {
    try {
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

        if (petData['documents'] is List) {
          for (final data in petData['documents']) {
            final Document document = Document.fromJson(data);
            await _dbHelper.insertDocument(
              document.copyWith(petId: newPetId),
            );
          }
        }

        if (petData['vitalSigns'] is List) {
          for (final data in petData['vitalSigns']) {
            final VitalSignRecord vitalSign = VitalSignRecord.fromJson(data);
            await _dbHelper.insertVitalSignRecord(
              vitalSign.copyWith(petId: newPetId),
            );
          }
        }

        if (petData['foodConfig'] != null) {
          final config = PetFoodConfig.fromJson(petData['foodConfig']);
          await _dbHelper.insertOrUpdateFoodConfig(
            PetFoodConfig(
              petId: newPetId,
              dailyGrams: config.dailyGrams,
              portions: config.portions,
              foodKcalPerKg: config.foodKcalPerKg,
            ),
          );
        }

        if (petData['medicationIntakes'] is List) {
          for (final data in petData['medicationIntakes']) {
            final intake = MedicationIntake.fromJson(data);
            await _dbHelper.insertMedicationIntake(
              MedicationIntake(
                id: intake.id,
                petId: newPetId,
                medicationId: intake.medicationId, // Se asume que medicationId es estable
                intakeDateTime: intake.intakeDateTime,
                medicationName: intake.medicationName,
              ),
            );
          }
        }
      }

      // Restaurar catálogos y contactos (fuera del bucle de mascotas)
      if (restoredData['dewormingProducts'] is List) {
        for (final data in restoredData['dewormingProducts']) {
          await _dbHelper.insertDewormingProduct(DewormingProduct.fromJson(data));
        }
      }
      if (restoredData['vaccinationProducts'] is List) {
        for (final data in restoredData['vaccinationProducts']) {
          await _dbHelper.insertVaccinationProduct(VaccinationProduct.fromJson(data));
        }
      }
      if (restoredData['emergencyContacts'] is List) {
        for (final data in restoredData['emergencyContacts']) {
          await _dbHelper.insertEmergencyContact(EmergencyContact.fromJson(data));
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