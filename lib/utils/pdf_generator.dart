import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart'; // Para formatear fechas
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/note.dart';
import 'package:pet_pal/models/vaccination.dart';
import 'package:pet_pal/models/medication.dart';
import 'package:pet_pal/models/deworming.dart';
import 'package:pet_pal/models/weight_record.dart';
import 'package:pet_pal/models/document.dart';
import 'package:pet_pal/models/pet_food_config.dart';
import 'package:pet_pal/models/emergency_contact.dart';
import 'package:pet_pal/models/food_allergy.dart';
import 'package:pet_pal/services/image_storage_service.dart';

Future<Uint8List> generateNotesPdf(Pet pet, List<Note> notes) async {
  final pdf = pw.Document();

  // Cargar una fuente para que el PDF se vea bien en diferentes visores
  // final font = await PdfGoogleFonts.openSansRegular(); // Requiere 'google_fonts' si usas fuentes de Google

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Cuaderno de Notas de ${pet.name}',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Generado el: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.Divider(),
            pw.SizedBox(height: 10),
          ],
        );
      },
      build: (pw.Context context) {
        if (notes.isEmpty) {
          return [
            pw.Center(
              child: pw.Text('No hay notas registradas para esta mascota.', style: const pw.TextStyle(fontSize: 16)),
            )
          ];
        }

        return [
          for (var note in notes) ...[
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              padding: const pw.EdgeInsets.all(10),
              margin: const pw.EdgeInsets.only(bottom: 15),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Fecha: ${DateFormat('dd/MM/yyyy').format(note.date)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    note.content,
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  // Se accede a photoPaths.isNotEmpty y photoPaths.first
                  if (note.photoPaths.isNotEmpty) ...[
                    pw.SizedBox(height: 10),
                    pw.Center(
                      child: pw.Image(
                        pw.MemoryImage(
                          File(note.photoPaths.first).readAsBytesSync(),
                        ),
                        width: 200, // Ajusta el tamaño de la imagen en el PDF
                        height: 200,
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ];
      },
    ),
  );

  return pdf.save();
}

/// Ficha clínica consolidada de una mascota: vacunas, medicación,
/// desparasitación, peso e índice de documentos. No incrusta ni fusiona
/// archivos PDF de documentos, solo su índice (categoría/título/fecha);
/// si un documento es imagen, se incrusta una miniatura pequeña.
Future<Uint8List> generateHealthSummaryPdf(
  Pet pet, {
  required List<Vaccination> vaccinations,
  required List<Medication> medications,
  required List<Deworming> dewormings,
  required List<WeightRecord> weightRecords,
  required List<Document> documents,
  PetFoodConfig? foodConfig,
  List<EmergencyContact>? emergencyContacts,
}) async {
  final pdf = pw.Document();
  final DateTime now = DateTime.now();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Ficha Clínica de ${pet.name}',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Generado el: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.Divider(),
            pw.SizedBox(height: 10),
          ],
        );
      },
      build: (pw.Context context) {
        return [
          _buildPdfSectionTitle('Información General'),
          _buildPdfInfoBox([
            pw.Text('Nombre: ${pet.name}', style: const pw.TextStyle(fontSize: 11)),
            pw.Text('Especie: ${pet.species}', style: const pw.TextStyle(fontSize: 11)),
            pw.Text('Raza: ${pet.breed}', style: const pw.TextStyle(fontSize: 11)),
            pw.Text('Color: ${pet.color}', style: const pw.TextStyle(fontSize: 11)),
            pw.Text('Nacimiento: ${pet.formattedDob}', style: const pw.TextStyle(fontSize: 11)),
            pw.Text('Edad: ${pet.detailedAge}', style: const pw.TextStyle(fontSize: 11)),
            if (pet.microchipNumber != null)
              pw.Text('Microchip: ${pet.microchipNumber}', style: const pw.TextStyle(fontSize: 11)),
            pw.Text('Esterilizado/a: ${pet.isNeutered ? "Sí" : "No"}', style: const pw.TextStyle(fontSize: 11)),
            if (foodConfig != null)
              pw.Text('Ración Diaria: ${foodConfig.dailyGrams.toStringAsFixed(0)}g repartidos en ${foodConfig.portions} tomas', style: const pw.TextStyle(fontSize: 11)),
          ]),
          pw.SizedBox(height: 12),

          if (emergencyContacts != null && emergencyContacts.isNotEmpty) ...[
            _buildPdfSectionTitle('Contactos de Emergencia'),
            for (final contact in emergencyContacts)
              _buildPdfInfoBox([
                pw.Text('${contact.name} (${contact.category ?? "Otros"})', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                pw.Text('Tel: ${contact.phone}', style: const pw.TextStyle(fontSize: 11)),
              ]),
            pw.SizedBox(height: 12),
          ],

          _buildPdfSectionTitle('Vacunas'),
          if (vaccinations.isEmpty)
            _buildPdfEmptySection()
          else
            for (final vaccination in vaccinations) _buildVaccinationBox(vaccination),
          pw.SizedBox(height: 12),

          _buildPdfSectionTitle('Medicación'),
          if (medications.isEmpty)
            _buildPdfEmptySection()
          else
            for (final medication in medications) _buildMedicationBox(medication, now),
          pw.SizedBox(height: 12),

          _buildPdfSectionTitle('Desparasitación'),
          if (dewormings.isEmpty)
            _buildPdfEmptySection()
          else
            for (final deworming in dewormings) _buildDewormingBox(deworming, now),
          pw.SizedBox(height: 12),

          _buildPdfSectionTitle('Peso'),
          if (weightRecords.isEmpty)
            _buildPdfEmptySection()
          else
            _buildWeightTable(weightRecords),
          pw.SizedBox(height: 12),

          _buildPdfSectionTitle('Documentos'),
          if (documents.isEmpty)
            _buildPdfEmptySection()
          else
            for (final document in documents) _buildDocumentBox(document),
        ];
      },
    ),
  );

  return pdf.save();
}

/// Carnet de identificación de una mascota: foto, datos básicos y, a
/// modo de cartilla sanitaria, el historial de vacunas, desparasitaciones,
/// alergias alimentarias y peso. A diferencia de [generateHealthSummaryPdf],
/// no incluye medicación activa ni el índice de documentos.
Future<Uint8List> generatePetCardPdf(
  Pet pet, {
  required List<Vaccination> vaccinations,
  required List<Deworming> dewormings,
  required List<FoodAllergy> foodAllergies,
  required List<WeightRecord> weightRecords,
}) async {
  final pdf = pw.Document();
  final DateTime now = DateTime.now();

  Uint8List? photoBytes;
  if (ImageStorageService.isValidLocalFile(pet.imageUrl)) {
    photoBytes = File(pet.imageUrl!).readAsBytesSync();
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Carnet de Identificación de ${pet.name}',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Generado el: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.Divider(),
            pw.SizedBox(height: 10),
          ],
        );
      },
      build: (pw.Context context) {
        return [
          pw.Center(
            child: photoBytes != null
                ? pw.ClipRRect(
                    horizontalRadius: 12,
                    verticalRadius: 12,
                    child: pw.Image(
                      pw.MemoryImage(photoBytes),
                      width: 220,
                      height: 220,
                      fit: pw.BoxFit.cover,
                    ),
                  )
                : pw.Container(
                    width: 220,
                    height: 220,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: pw.BorderRadius.circular(12),
                    ),
                    child: pw.Center(
                      child: pw.Text('Sin foto', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ),
                  ),
          ),
          pw.SizedBox(height: 14),
          pw.Center(
            child: pw.Text(
              pet.name,
              style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              '${pet.species} · ${pet.breed}',
              style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
            ),
          ),
          pw.SizedBox(height: 16),

          _buildPdfInfoBox([
            _buildPetCardRow('Edad', pet.detailedAge),
            _buildPetCardRow('Nacimiento', pet.formattedDob),
            _buildPetCardRow('Color', pet.color),
            if (pet.microchipNumber != null && pet.microchipNumber!.isNotEmpty)
              _buildPetCardRow('Microchip', pet.microchipNumber!),
          ]),
          pw.SizedBox(height: 10),

          pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: pw.BoxDecoration(
                color: pet.isNeutered ? PdfColors.green50 : PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                pet.isNeutered ? 'Esterilizado/a' : 'No esterilizado/a',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: pet.isNeutered ? PdfColors.green700 : PdfColors.grey700,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 20),

          _buildPdfSectionTitle('Vacunas'),
          if (vaccinations.isEmpty)
            _buildPdfEmptySection()
          else
            for (final vaccination in vaccinations) _buildVaccinationBox(vaccination),
          pw.SizedBox(height: 12),

          _buildPdfSectionTitle('Desparasitación'),
          if (dewormings.isEmpty)
            _buildPdfEmptySection()
          else
            for (final deworming in dewormings) _buildDewormingBox(deworming, now),
          pw.SizedBox(height: 12),

          _buildPdfSectionTitle('Alergias Alimentarias'),
          if (foodAllergies.isEmpty)
            _buildPdfEmptySection()
          else
            for (final foodAllergy in foodAllergies) _buildFoodAllergyBox(foodAllergy),
          pw.SizedBox(height: 12),

          _buildPdfSectionTitle('Peso'),
          if (weightRecords.isEmpty)
            _buildPdfEmptySection()
          else
            _buildWeightTable(weightRecords),
        ];
      },
    ),
  );

  return pdf.save();
}

pw.Widget _buildPetCardRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 90,
          child: pw.Text(label, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Expanded(
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
        ),
      ],
    ),
  );
}

pw.Widget _buildFoodAllergyBox(FoodAllergy foodAllergy) {
  return _buildPdfInfoBox([
    pw.Text(
      foodAllergy.food,
      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
    ),
    pw.SizedBox(height: 3),
    pw.Text(
      'Fecha registrada: ${DateFormat('dd/MM/yyyy').format(foodAllergy.dateRecorded)}',
      style: const pw.TextStyle(fontSize: 11),
    ),
  ]);
}

pw.Widget _buildPdfSectionTitle(String title) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Text(
      title,
      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
    ),
  );
}

pw.Widget _buildPdfEmptySection() {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 15),
    child: pw.Text(
      'Sin registros.',
      style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic),
    ),
  );
}

pw.Widget _buildPdfInfoBox(List<pw.Widget> children) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: pw.BorderRadius.circular(5),
    ),
    padding: const pw.EdgeInsets.all(10),
    margin: const pw.EdgeInsets.only(bottom: 10),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: children),
  );
}

pw.Widget _buildVaccinationBox(Vaccination vaccination) {
  return _buildPdfInfoBox([
    pw.Text(
      vaccination.vaccineName,
      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
    ),
    pw.SizedBox(height: 3),
    pw.Text(
      'Fecha aplicada: ${DateFormat('dd/MM/yyyy').format(vaccination.date)}',
      style: const pw.TextStyle(fontSize: 11),
    ),
    if (vaccination.nextDueDate != null)
      pw.Text(
        'Próxima dosis: ${DateFormat('dd/MM/yyyy').format(vaccination.nextDueDate!)}',
        style: const pw.TextStyle(fontSize: 11),
      ),
  ]);
}

pw.Widget _buildMedicationBox(Medication medication, DateTime now) {
  final bool isFinished = medication.endDate != null && medication.endDate!.isBefore(now);
  final String range = medication.endDate != null
      ? '${DateFormat('dd/MM/yyyy').format(medication.startDate)} - '
          '${DateFormat('dd/MM/yyyy').format(medication.endDate!)}'
      : '${DateFormat('dd/MM/yyyy').format(medication.startDate)} - Indefinido';

  return _buildPdfInfoBox([
    pw.Text(
      medication.name,
      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
    ),
    pw.SizedBox(height: 3),
    pw.Text('Dosis: ${medication.dosage}', style: const pw.TextStyle(fontSize: 11)),
    if (medication.frequency.isNotEmpty)
      pw.Text('Frecuencia: ${medication.frequency}', style: const pw.TextStyle(fontSize: 11)),
    if (medication.notes.isNotEmpty)
      pw.Text('Notas: ${medication.notes}', style: const pw.TextStyle(fontSize: 11)),
    pw.Text('Rango: $range', style: const pw.TextStyle(fontSize: 11)),
    pw.Text(
      isFinished ? 'Finalizada' : 'En curso',
      style: pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: isFinished ? PdfColors.grey700 : PdfColors.green700,
      ),
    ),
  ]);
}

pw.Widget _buildDewormingBox(Deworming deworming, DateTime now) {
  final String statusLabel;
  final PdfColor statusColor;
  final bool isOverdue;

  if (deworming.nextDate == null) {
    statusLabel = 'Aplicada, sin próxima dosis programada';
    statusColor = PdfColors.grey700;
    isOverdue = false;
  } else if (deworming.nextDate!.isBefore(now)) {
    statusLabel = 'Vencida — requiere nueva dosis';
    statusColor = PdfColors.red700;
    isOverdue = true;
  } else {
    statusLabel = 'Vigente hasta ${DateFormat('dd/MM/yyyy').format(deworming.nextDate!)}';
    statusColor = PdfColors.green700;
    isOverdue = false;
  }

  final pw.Widget statusText = pw.Text(
    statusLabel,
    style: pw.TextStyle(
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
      color: statusColor,
    ),
  );

  String typeLabel = '';
  if (deworming.type != null) {
    typeLabel = ' (${deworming.type![0].toUpperCase()}${deworming.type!.substring(1)})';
  }

  return _buildPdfInfoBox([
    pw.Text(
      '${deworming.product}$typeLabel',
      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
    ),
    pw.SizedBox(height: 3),
    pw.Text(
      'Fecha aplicada: ${DateFormat('dd/MM/yyyy').format(deworming.date)}',
      style: const pw.TextStyle(fontSize: 11),
    ),
    if (deworming.frequencyMonths != null)
      pw.Text(
        'Frecuencia: cada ${deworming.frequencyMonths} mes${deworming.frequencyMonths! > 1 ? 'es' : ''}',
        style: const pw.TextStyle(fontSize: 11),
      ),
    pw.Text(
      deworming.nextDate != null
          ? 'Próxima aplicación: ${DateFormat('dd/MM/yyyy').format(deworming.nextDate!)}'
          : 'Próxima aplicación: No especificada',
      style: const pw.TextStyle(fontSize: 11),
    ),
    pw.SizedBox(height: 3),
    if (isOverdue)
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: pw.BoxDecoration(
          color: PdfColors.red50,
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: statusText,
      )
    else
      statusText,
  ]);
}

pw.Widget _buildWeightTable(List<WeightRecord> weightRecords) {
  final List<WeightRecord> sorted = List.of(weightRecords)
    ..sort((a, b) => a.date.compareTo(b.date));

  return pw.TableHelper.fromTextArray(
    headers: ['Fecha', 'Peso (kg)'],
    data: sorted
        .map((record) => [
              DateFormat('dd/MM/yyyy').format(record.date),
              record.weight.toStringAsFixed(2),
            ])
        .toList(),
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
    cellStyle: const pw.TextStyle(fontSize: 10),
    cellAlignment: pw.Alignment.centerLeft,
    border: pw.TableBorder.all(color: PdfColors.grey300),
  );
}

pw.Widget _buildDocumentBox(Document document) {
  Uint8List? thumbnailBytes;
  if (document.isImage) {
    try {
      final File file = File(document.filePath);
      if (file.existsSync()) {
        thumbnailBytes = file.readAsBytesSync();
      }
    } catch (_) {
      // Archivo no disponible: se omite la miniatura, el documento sigue
      // apareciendo en el índice igualmente.
      thumbnailBytes = null;
    }
  }

  return _buildPdfInfoBox([
    pw.Text(
      '${document.categoria}: ${document.titulo}',
      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
    ),
    pw.SizedBox(height: 3),
    pw.Text(
      'Fecha: ${DateFormat('dd/MM/yyyy').format(document.fecha)}',
      style: const pw.TextStyle(fontSize: 11),
    ),
    if (thumbnailBytes != null) ...[
      pw.SizedBox(height: 8),
      pw.Image(
        pw.MemoryImage(thumbnailBytes),
        width: 80,
        height: 80,
        fit: pw.BoxFit.cover,
      ),
    ],
  ]);
}