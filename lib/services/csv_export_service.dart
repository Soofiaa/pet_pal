import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/utils/csv_export_generator.dart';

/// Genera y comparte archivos CSV con el historial de una mascota,
/// siguiendo el mismo patrón de generar-en-temp-y-compartir que
/// DataBackupService.exportAllData() usa para el backup completo.
class CsvExportService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<String> exportWeightHistory(Pet pet) async {
    try {
      final records = await _dbHelper.getWeightRecordsForPet(pet.id);
      final csv = generateWeightRecordsCsv(records);
      await _shareCsv(csv, 'peso', pet);
      return 'Historial de peso exportado con éxito.';
    } catch (e) {
      return 'Error al exportar el historial de peso: $e';
    }
  }

  Future<String> exportVaccinationHistory(Pet pet) async {
    try {
      final vaccinations = await _dbHelper.getVaccinationsForPet(pet.id);
      final csv = generateVaccinationsCsv(vaccinations);
      await _shareCsv(csv, 'vacunas', pet);
      return 'Historial de vacunas exportado con éxito.';
    } catch (e) {
      return 'Error al exportar el historial de vacunas: $e';
    }
  }

  Future<String> exportMedicationHistory(Pet pet) async {
    try {
      final medications = await _dbHelper.getMedicationsForPet(pet.id);
      final csv = generateMedicationsCsv(medications);
      await _shareCsv(csv, 'medicacion', pet);
      return 'Historial de medicación exportado con éxito.';
    } catch (e) {
      return 'Error al exportar el historial de medicación: $e';
    }
  }

  Future<String> exportDewormingHistory(Pet pet) async {
    try {
      final dewormings = await _dbHelper.getDewormingsForPet(pet.id);
      final csv = generateDewormingsCsv(dewormings);
      await _shareCsv(csv, 'desparasitacion', pet);
      return 'Historial de desparasitación exportado con éxito.';
    } catch (e) {
      return 'Error al exportar el historial de desparasitación: $e';
    }
  }

  Future<void> _shareCsv(String csvContent, String kind, Pet pet) async {
    final Uint8List bytes = Uint8List.fromList(utf8.encode(csvContent));

    final Directory tempDir = await getTemporaryDirectory();
    final String fileName =
        'pet_pal_${kind}_${pet.name}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';

    final File file = File(p.join(tempDir.path, fileName));
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Historial de $kind de ${pet.name}',
    );
  }
}
