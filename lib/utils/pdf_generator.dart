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
import 'package:pet_pal/models/dashboard_event.dart';
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
      build: (pw.Context context) => buildHealthSummarySections(
        pet,
        vaccinations: vaccinations,
        medications: medications,
        dewormings: dewormings,
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
      ..._buildGroupedVaccinationSection(vaccinations),
      pw.SizedBox(height: 12),
    ],

    if (medications.isNotEmpty) ...[
      _buildPdfSectionTitle('Medicación'),
      for (final medication in medications) _buildMedicationBox(medication, now),
      pw.SizedBox(height: 12),
    ],

    if (dewormings.isNotEmpty) ...[
      _buildPdfSectionTitle('Desparasitación'),
      ..._buildGroupedDewormingSection(dewormings, now),
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
            ..._buildGroupedVaccinationSection(vaccinations),
          pw.SizedBox(height: 12),

          _buildPdfSectionTitle('Desparasitación'),
          if (dewormings.isEmpty)
            _buildPdfEmptySection()
          else
            ..._buildGroupedDewormingSection(dewormings, now),
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

/// Foto de perfil de la mascota para la ficha clínica -mismo manejo de
/// archivo/placeholder que ya usa generatePetCardPdf, en un tamaño más
/// chico acorde a un reporte en vez de una tarjeta de identificación-.
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

/// Agrupa [items] por el nombre que devuelve [nameOf] y ordena cada grupo
/// por [dateOf] descendente (más reciente primero). Genérica -no es
/// específica de desparasitaciones ni vacunas- porque ambas Tareas 1 y 2
/// necesitan la misma organización de datos para mostrar el historial
/// completo agrupado. Pública para poder testearla directo (mismo motivo
/// que normalizeForSearch en search_service.dart). A diferencia de
/// [DashboardEvent.idsOfMostRecentApplicationPerName] -que decide un único
/// "ganador" por nombre-, esta función no descarta nada: es solo
/// organización para mostrar el historial completo, no una deduplicación.
Map<String, List<T>> groupByNameSortedByDateDesc<T>(
  List<T> items,
  String Function(T) nameOf,
  DateTime Function(T) dateOf,
) {
  final Map<String, List<T>> grouped = {};
  for (final item in items) {
    grouped.putIfAbsent(nameOf(item), () => []).add(item);
  }
  for (final group in grouped.values) {
    group.sort((a, b) => dateOf(b).compareTo(dateOf(a)));
  }
  return grouped;
}

/// Ids de las desparasitaciones que deben mostrar el badge de vigente/
/// vencida: solo la aplicación más reciente de cada producto. Reutiliza
/// literalmente [DashboardEvent.idsOfMostRecentApplicationPerName] -el
/// mismo criterio que ya usa el panel "Hoy" para deduplicar-, no
/// reimplementa el criterio, para que el PDF y el dashboard nunca puedan
/// discrepar sobre cuál aplicación es la vigente. Pública para poder
/// testearla directo.
Set<String?> dewormingIdsWithUrgencyBadge(List<Deworming> dewormings) {
  final events = Deworming.getEventsFromList(dewormings);
  return DashboardEvent.idsOfMostRecentApplicationPerName(events, 'deworming')
      .cast<String?>();
}

/// Sección de desparasitaciones agrupada por producto (Tarea 1): dentro de
/// cada grupo, ordenadas por fecha de aplicación descendente. Solo la
/// aplicación más reciente de cada producto -según
/// [dewormingIdsWithUrgencyBadge]- muestra el badge de vigente/vencida;
/// las anteriores del mismo producto se muestran como historial plano, sin
/// badge de urgencia (antes, cada aplicación evaluaba su propio nextDate
/// de forma aislada, así que casi todo el historial se veía "Vencida"
/// aunque ya hubiera sido reemplazada a tiempo por una más nueva).
List<pw.Widget> _buildGroupedDewormingSection(List<Deworming> dewormings, DateTime now) {
  final winnerIds = dewormingIdsWithUrgencyBadge(dewormings);
  final grouped = groupByNameSortedByDateDesc(dewormings, (d) => d.product, (d) => d.date);

  final List<pw.Widget> widgets = [];
  for (final group in grouped.values) {
    for (final deworming in group) {
      widgets.add(
        winnerIds.contains(deworming.id)
            ? _buildDewormingBox(deworming, now)
            : _buildDewormingHistoryBox(deworming),
      );
    }
  }
  return widgets;
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

/// Sección de vacunas agrupada por nombre (Tarea 2): dentro de cada grupo,
/// una línea de fecha por aplicación y, debajo, todas las fotos de todas
/// las aplicaciones de ese nombre juntas -a diferencia de la Tarea 1, acá
/// no hay "ganador": es historial visual completo, no una alerta de
/// urgencia-.
List<pw.Widget> _buildGroupedVaccinationSection(List<Vaccination> vaccinations) {
  final grouped = groupByNameSortedByDateDesc(vaccinations, (v) => v.vaccineName, (v) => v.date);
  return [
    for (final entry in grouped.entries) _buildVaccinationGroupBox(entry.key, entry.value),
  ];
}

pw.Widget _buildVaccinationGroupBox(String vaccineName, List<Vaccination> applications) {
  final List<_VaccinationPhoto> photos = [];
  for (final application in applications) {
    if (ImageStorageService.isValidLocalFile(application.stickerPhotoPath)) {
      photos.add(_VaccinationPhoto(application.stickerPhotoPath!, application.date, 'Adhesivo'));
    }
    if (ImageStorageService.isValidLocalFile(application.extraPhotoPath)) {
      photos.add(_VaccinationPhoto(application.extraPhotoPath!, application.date, 'Extra'));
    }
  }

  return _buildPdfInfoBox([
    pw.Text(
      vaccineName,
      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
    ),
    pw.SizedBox(height: 3),
    for (final application in applications)
      pw.Text(
        'Fecha aplicada: ${DateFormat('dd/MM/yyyy').format(application.date)}'
        '${application.nextDueDate != null ? ' · Próxima dosis: ${DateFormat('dd/MM/yyyy').format(application.nextDueDate!)}' : ''}',
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
                    pw.MemoryImage(File(photo.path).readAsBytesSync()),
                    width: 60,
                    height: 60,
                    fit: pw.BoxFit.cover,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  '${photo.label} · ${DateFormat('dd/MM/yy').format(photo.date)}',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                ),
              ],
            ),
        ],
      ),
    ],
  ]);
}

class _VaccinationPhoto {
  _VaccinationPhoto(this.path, this.date, this.label);

  final String path;
  final DateTime date;
  final String label;
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