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
  required List<FoodAllergy> foodAllergies,
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
      build: (pw.Context context) => buildHealthSummarySections(
        pet,
        vaccinations: vaccinations,
        medications: medications,
        dewormings: dewormings,
        foodAllergies: foodAllergies,
        weightRecords: weightRecords,
        documents: documents,
        foodConfig: foodConfig,
        emergencyContacts: emergencyContacts,
        now: now,
      ),
    ),
  );

  return pdf.save();
}

/// Contenido de la ficha clínica, separado del `build:` de
/// [generateHealthSummaryPdf] específicamente para poder testearlo
/// directo -recorriendo el árbol de widgets real que se termina
/// renderizando- sin tener que generar y decodificar bytes de PDF.
///
/// Cada sección (salvo Información General, siempre visible) se omite
/// por completo -ni título ni "Sin registros"- cuando su lista está
/// vacía, en vez de mostrarse vacía.
List<pw.Widget> buildHealthSummarySections(
  Pet pet, {
  required List<Vaccination> vaccinations,
  required List<Medication> medications,
  required List<Deworming> dewormings,
  required List<FoodAllergy> foodAllergies,
  required List<WeightRecord> weightRecords,
  required List<Document> documents,
  PetFoodConfig? foodConfig,
  List<EmergencyContact>? emergencyContacts,
  required DateTime now,
}) {
  return [
    _buildPdfSectionTitle('Información General'),
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildPetPhoto(pet, size: 100),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: _buildPdfInfoBox(
            _buildTwoColumnRows([
              MapEntry('Nombre', pet.name),
              MapEntry('Especie', pet.species),
              MapEntry('Raza', pet.breed),
              MapEntry('Color', pet.color),
              MapEntry('Nacimiento', pet.formattedDob),
              MapEntry('Edad', pet.detailedAge),
              if (pet.microchipNumber != null && pet.microchipNumber!.isNotEmpty)
                MapEntry('Microchip', pet.microchipNumber!),
              MapEntry('Esterilizado/a', pet.isNeutered ? 'Sí' : 'No'),
              if (foodConfig != null)
                MapEntry(
                  'Ración Diaria',
                  '${foodConfig.dailyGrams.toStringAsFixed(0)}g / ${foodConfig.portions} tomas',
                ),
            ]),
          ),
        ),
      ],
    ),
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

    if (vaccinations.isNotEmpty) ...[
      _buildPdfSectionTitle('Vacunas'),
      ..._buildVaccinationSection(vaccinations),
      pw.SizedBox(height: 12),
    ],

    if (medications.isNotEmpty) ...[
      _buildPdfSectionTitle('Medicación'),
      for (final medication in medications) _buildMedicationBox(medication, now),
      pw.SizedBox(height: 12),
    ],

    if (dewormings.isNotEmpty) ...[
      _buildPdfSectionTitle('Desparasitación'),
      ..._buildDewormingSection(dewormings, now),
      pw.SizedBox(height: 12),
    ],

    if (foodAllergies.isNotEmpty) ...[
      _buildPdfSectionTitle('Alergias Alimentarias'),
      for (final foodAllergy in foodAllergies) _buildFoodAllergyBox(foodAllergy),
      pw.SizedBox(height: 12),
    ],

    if (weightRecords.isNotEmpty) ...[
      _buildPdfSectionTitle('Peso'),
      _buildWeightTable(weightRecords),
      pw.SizedBox(height: 12),
    ],

    if (documents.isNotEmpty) ...[
      _buildPdfSectionTitle('Documentos'),
      for (final document in documents) _buildDocumentBox(document),
      pw.SizedBox(height: 12),
    ],
  ];
}

/// Foto de perfil de la mascota para la ficha clínica: archivo local si
/// existe, o un placeholder si no.
pw.Widget _buildPetPhoto(Pet pet, {required double size}) {
  Uint8List? photoBytes;
  if (ImageStorageService.isValidLocalFile(pet.imageUrl)) {
    photoBytes = File(pet.imageUrl!).readAsBytesSync();
  }

  if (photoBytes != null) {
    return pw.ClipRRect(
      horizontalRadius: 8,
      verticalRadius: 8,
      child: pw.Image(
        pw.MemoryImage(photoBytes),
        width: size,
        height: size,
        fit: pw.BoxFit.cover,
      ),
    );
  }

  return pw.Container(
    width: size,
    height: size,
    decoration: pw.BoxDecoration(
      color: PdfColors.grey200,
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Center(
      child: pw.Text('Sin foto', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
    ),
  );
}

/// Empareja [fields] de a dos por fila -aprovecha el ancho de página en
/// vez de una línea por dato con mucho espacio en blanco a la derecha-.
/// Si la cantidad es impar, la última fila queda con una sola celda.
List<pw.Widget> _buildTwoColumnRows(List<MapEntry<String, String>> fields) {
  final List<pw.Widget> rows = [];
  for (int i = 0; i < fields.length; i += 2) {
    final pw.Widget first = _buildInfoField(fields[i]);
    final pw.Widget? second = i + 1 < fields.length ? _buildInfoField(fields[i + 1]) : null;
    rows.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: first),
            pw.SizedBox(width: 12),
            pw.Expanded(child: second ?? pw.SizedBox()),
          ],
        ),
      ),
    );
  }
  return rows;
}

pw.Widget _buildInfoField(MapEntry<String, String> field) {
  return pw.RichText(
    text: pw.TextSpan(
      children: [
        pw.TextSpan(
          text: '${field.key}: ',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.TextSpan(
          text: field.value,
          style: const pw.TextStyle(fontSize: 11),
        ),
      ],
    ),
  );
}

/// Id de la desparasitación que debe mostrar el badge de vigente/vencida:
/// la aplicación más reciente de TODAS, sin importar el producto -la
/// desparasitación de una mascota es una sola línea de tiempo, no una por
/// producto-. Confirmado contra un caso real con 5 productos distintos: el
/// panel "Hoy" ya trata la desparasitación de una mascota como una sola
/// línea (no agrupa por nombre de producto), así que la ficha clínica debe
/// reflejar el mismo criterio. A diferencia de las vacunas -que sí tienen
/// una "próxima dosis" propia por vacuna distinta-, cambiar de marca de
/// antiparasitario no abre una línea de vigencia independiente.
///
/// Específica y exclusiva de pdf_generator.dart: NO reutiliza ni afecta
/// [DashboardEvent.idsOfMostRecentApplicationPerName] (que agrupa por
/// nombre de producto y es el criterio correcto para el panel "Hoy", pero
/// no para esta ficha). Pública para poder testearla directo.
Set<String?> dewormingIdsWithUrgencyBadge(List<Deworming> dewormings) {
  if (dewormings.isEmpty) return {};
  Deworming winner = dewormings.first;
  for (final deworming in dewormings.skip(1)) {
    if (deworming.date.isAfter(winner.date)) winner = deworming;
  }
  return {winner.id};
}

/// Sección de desparasitación: lista plana ordenada por fecha de
/// aplicación descendente (más reciente primero). Solo la aplicación más
/// reciente de todas -según [dewormingIdsWithUrgencyBadge]- muestra el
/// badge de vigente/vencida; el resto se muestra como historial plano, sin
/// badge, sin importar su propio producto o fecha individual.
List<pw.Widget> _buildDewormingSection(List<Deworming> dewormings, DateTime now) {
  final winnerIds = dewormingIdsWithUrgencyBadge(dewormings);
  final sorted = List<Deworming>.of(dewormings)..sort((a, b) => b.date.compareTo(a.date));
  return [
    for (final deworming in sorted)
      winnerIds.contains(deworming.id)
          ? _buildDewormingBox(deworming, now)
          : _buildDewormingHistoryBox(deworming),
  ];
}

/// Caja de historial plano para una aplicación de desparasitación que ya
/// fue superada por una más reciente del mismo producto (Tarea 1): solo
/// producto y fecha aplicada, sin badge de vigente/vencida -esa urgencia
/// ya no aplica a un registro histórico-.
pw.Widget _buildDewormingHistoryBox(Deworming deworming) {
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
  ]);
}

/// Sección de vacunas: lista plana ordenada por fecha de aplicación
/// descendente (más reciente primero), sin agrupar por nombre de vacuna.
List<pw.Widget> _buildVaccinationSection(List<Vaccination> vaccinations) {
  final sorted = List<Vaccination>.of(vaccinations)..sort((a, b) => b.date.compareTo(a.date));
  return [for (final vaccination in sorted) _buildVaccinationBox(vaccination)];
}

pw.Widget _buildVaccinationBox(Vaccination vaccination) {
  final List<MapEntry<String, String>> photos = [];
  if (ImageStorageService.isValidLocalFile(vaccination.stickerPhotoPath)) {
    photos.add(MapEntry(vaccination.stickerPhotoPath!, 'Adhesivo'));
  }
  if (ImageStorageService.isValidLocalFile(vaccination.extraPhotoPath)) {
    photos.add(MapEntry(vaccination.extraPhotoPath!, 'Extra'));
  }

  return _buildPdfInfoBox([
    pw.Text(
      vaccination.vaccineName,
      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
    ),
    pw.SizedBox(height: 3),
    pw.Text(
      'Fecha aplicada: ${DateFormat('dd/MM/yyyy').format(vaccination.date)}'
      '${vaccination.nextDueDate != null ? ' · Próxima dosis: ${DateFormat('dd/MM/yyyy').format(vaccination.nextDueDate!)}' : ''}',
      style: const pw.TextStyle(fontSize: 11),
    ),
    if (photos.isNotEmpty) ...[
      pw.SizedBox(height: 8),
      pw.Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final photo in photos)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.ClipRRect(
                  horizontalRadius: 6,
                  verticalRadius: 6,
                  child: pw.Image(
                    pw.MemoryImage(File(photo.key).readAsBytesSync()),
                    width: 60,
                    height: 60,
                    fit: pw.BoxFit.cover,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  photo.value,
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                ),
              ],
            ),
        ],
      ),
    ],
  ]);
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

  // effectiveNextDate(), no nextDate crudo: para desparasitaciones
  // recurrentes, avanza la fecha en múltiplos de frequencyMonths hasta
  // quedar vigente -si no, se mostraba "Vencida" para siempre en cuanto
  // pasaba el primer ciclo, aunque el recordatorio ya se hubiera
  // reprogramado solo-.
  final DateTime? effectiveNextDate = deworming.effectiveNextDate(now: now);

  if (effectiveNextDate == null) {
    statusLabel = 'Aplicada, sin próxima dosis programada';
    statusColor = PdfColors.grey700;
    isOverdue = false;
  } else if (effectiveNextDate.isBefore(now)) {
    statusLabel = 'Vencida — requiere nueva dosis';
    statusColor = PdfColors.red700;
    isOverdue = true;
  } else {
    statusLabel = 'Vigente hasta ${DateFormat('dd/MM/yyyy').format(effectiveNextDate)}';
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
      effectiveNextDate != null
          ? 'Próxima aplicación: ${DateFormat('dd/MM/yyyy').format(effectiveNextDate)}'
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