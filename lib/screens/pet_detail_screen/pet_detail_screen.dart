import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/pet.dart';
// ignore: library_prefixes
import '../../utils/pdf_generator.dart' as PdfGenerator;
import 'package:pet_pal/screens/add_edit_pet_screen/add_edit_pet_screen.dart';
import 'package:pet_pal/screens/vaccinations_screen/vaccinations_screen.dart';
import 'package:pet_pal/screens/appointments_screen/appointments_screen.dart';
import 'package:pet_pal/screens/weight_record_screen/weight_record_screen.dart';
import 'package:pet_pal/screens/food_allergy_screen/food_allergy_screen.dart';
import 'package:pet_pal/screens/food_record_screen/food_record_screen.dart';
import 'package:pet_pal/screens/notes_screen/notes_screen.dart';
import 'package:pet_pal/screens/calendar_screen/calendar_screen.dart';
import 'package:pet_pal/screens/deworming_screen/deworming_screen.dart';
import 'package:pet_pal/screens/medications_screen/medications_screen.dart';
import 'package:pet_pal/screens/documents_screen/documents_screen.dart';
import 'package:pet_pal/screens/image_preview_screen/image_preview_screen.dart';
import 'package:pet_pal/screens/vital_sign_screen/vital_sign_screen.dart';
import 'package:pet_pal/models/vital_sign_config.dart';
import 'package:pet_pal/services/image_storage_service.dart';
import 'package:pet_pal/services/csv_export_service.dart';
import 'package:pet_pal/theme/category_colors.dart';
import 'package:pet_pal/utils/entity_colors.dart';
import 'package:pet_pal/utils/delete_pet_flow.dart';

class PetDetailScreen extends StatefulWidget {
  final Pet pet;

  const PetDetailScreen({super.key, required this.pet});

  @override
  State<PetDetailScreen> createState() => _PetDetailScreenState();
}

class _PetDetailScreenState extends State<PetDetailScreen> {
  late Pet _pet;
  bool _isGeneratingHealthSummary = false;
  final CsvExportService _csvExportService = CsvExportService();

  @override
  void initState() {
    super.initState();
    _pet = widget.pet;
  }

  Future<void> _reloadPet() async {
    final updated = await DatabaseHelper().getPetById(_pet.id);
    if (updated != null && mounted) {
      setState(() => _pet = updated);
    }
  }

  Future<void> _deletePet() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final name = _pet.name;
    final deleted = await confirmAndDeletePet(context, _pet);
    if (!deleted) return;
    messenger.showSnackBar(SnackBar(content: Text('$name eliminada con éxito.')));
    navigator.pop();
  }

  Future<void> _generateAndShareHealthSummary() async {
    setState(() => _isGeneratingHealthSummary = true);

    try {
      final dbHelper = DatabaseHelper();
      final vaccinations = await dbHelper.getVaccinationsForPet(_pet.id);
      final medications = await dbHelper.getMedicationsForPet(_pet.id);
      final dewormings = await dbHelper.getDewormingsForPet(_pet.id);
      final foodAllergies = await dbHelper.getFoodAllergiesForPet(_pet.id);
      final weightRecords = await dbHelper.getWeightRecordsForPet(_pet.id);
      final documents = await dbHelper.getDocumentsForPet(_pet.id);
      final emergencyContacts = await dbHelper.getEmergencyContacts();
      final foodConfig = await dbHelper.getFoodConfigForPet(_pet.id);

      final pdfData = await PdfGenerator.generateHealthSummaryPdf(
        _pet,
        vaccinations: vaccinations,
        medications: medications,
        dewormings: dewormings,
        foodAllergies: foodAllergies,
        weightRecords: weightRecords,
        documents: documents,
        emergencyContacts: emergencyContacts,
        foodConfig: foodConfig,
      );

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/ficha_clinica_${_pet.name}.pdf');
      await file.writeAsBytes(pdfData);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Ficha clínica de ${_pet.name}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al generar la ficha clínica.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingHealthSummary = false);
      }
    }
  }

  Future<void> _exportCsvHistory(String kind) async {
    String result;
    switch (kind) {
      case 'weight':
        result = await _csvExportService.exportWeightHistory(_pet);
        break;
      case 'vaccinations':
        result = await _csvExportService.exportVaccinationHistory(_pet);
        break;
      case 'medications':
        result = await _csvExportService.exportMedicationHistory(_pet);
        break;
      case 'deworming':
        result = await _csvExportService.exportDewormingHistory(_pet);
        break;
      default:
        return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> features = [
      {
        'title': 'Alergias',
        'icon': Icons.warning_amber,
        'color': entityColorFor('food_allergy'),
        'group': 'Salud',
        'onTap': () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => FoodAllergyScreen(pet: _pet)));
        },
      },
      {
        'title': 'Alimentos',
        'icon': Icons.restaurant,
        'color': entityColorFor('food_record'),
        'group': 'Historial',
        'onTap': () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => FoodRecordScreen(pet: _pet)));
        },
      },
      {
        'title': 'Citas',
        'icon': Icons.event,
        'color': entityColorFor('appointment'),
        'group': 'Otros',
        'onTap': () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => AppointmentsScreen(pet: _pet)));
        },
      },
      {
        'title': 'Documentos',
        'icon': Icons.folder_shared,
        'color': entityColorFor('document'),
        'group': 'Historial',
        'onTap': () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => DocumentsScreen(pet: _pet)));
        },
      },
      {
        'title': 'Desparasitaciones',
        'icon': Icons.medication,
        'color': entityColorFor('deworming'),
        'group': 'Salud',
        'onTap': () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => DewormingScreen(pet: _pet)));
        },
      },
      {
        'title': 'Medicación',
        'icon': Icons.medication_liquid,
        'color': entityColorFor('medication'),
        'group': 'Salud',
        'onTap': () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => MedicationsScreen(pet: _pet)));
        },
      },
      {
        'title': 'Notas',
        'icon': Icons.note,
        'color': entityColorFor('note'),
        'group': 'Historial',
        'onTap': () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => NotesScreen(pet: _pet)));
        },
      },
      {
        'title': 'Peso',
        'icon': Icons.monitor_weight,
        'color': entityColorFor('weight'),
        'group': 'Historial',
        'onTap': () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => WeightRecordScreen(pet: _pet)));
        },
      },
      {
        'title': 'Vacunas',
        'icon': Icons.vaccines,
        'color': entityColorFor('vaccination'),
        'group': 'Salud',
        'onTap': () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => VaccinationsScreen(pet: _pet)));
        },
      },
      {
        'title': 'Signos Vitales',
        'icon': Icons.thermostat,
        'color': entityColorFor('vital_sign'),
        'group': 'Salud',
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VitalSignScreen(pet: _pet, type: VitalSignType.temperature),
            ),
          );
        },
      },
    ];

    features.sort((a, b) => (a['title'] as String).compareTo(b['title'] as String));

    const List<String> featureGroupOrder = ['Salud', 'Historial', 'Otros'];

    const int crossAxisCount = 3;
    const double crossAxisSpacing = 10;
    const double mainAxisSpacing = 10;
    const double horizontalPadding = 8.0;

    final screenWidth = MediaQuery.of(context).size.width;
    final gridItemWidth =
        (screenWidth - (horizontalPadding * 2) - (crossAxisSpacing * (crossAxisCount - 1))) / crossAxisCount;

    // Alto de tarjeta calculado con la fuente ya acotada (ver _buildFeatureCard)
    // para que no desborde con texto grande.
    final featureLabelHeight = _featureLabelScaler(context).scale(12) * 1.4 * 2;
    final featureCardHeight = max(gridItemWidth, 50 + 8 + featureLabelHeight + 16);

    final microchipText = (_pet.microchipNumber == null || _pet.microchipNumber!.isEmpty)
        ? 'No registrado'
        : _pet.microchipNumber!;

    final microchipHasValue = (_pet.microchipNumber != null && _pet.microchipNumber!.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: Text(_pet.name),
        actions: [
          if (_isGeneratingHealthSummary)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Más opciones',
              onSelected: (value) {
                if (value == 'pdf') {
                  _generateAndShareHealthSummary();
                } else if (value == 'delete') {
                  _deletePet();
                } else {
                  _exportCsvHistory(value);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'pdf',
                  child: ListTile(
                    leading: Icon(Icons.picture_as_pdf),
                    title: Text('Ficha clínica (PDF)'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  enabled: false,
                  child: Text('Exportar historial (CSV)'),
                ),
                PopupMenuItem(value: 'weight', child: Text('Historial de peso')),
                PopupMenuItem(value: 'vaccinations', child: Text('Historial de vacunas')),
                PopupMenuItem(value: 'medications', child: Text('Historial de medicación')),
                PopupMenuItem(value: 'deworming', child: Text('Historial de desparasitación')),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Eliminar mascota'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Editar mascota',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddEditPetScreen(pet: _pet)),
              );
              await _reloadPet();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: ImageStorageService.isValidLocalFile(_pet.imageUrl)
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ImagePreviewScreen(
                                  imagePath: _pet.imageUrl!,
                                  title: _pet.name,
                                ),
                              ),
                            );
                          }
                        : null,
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: _pet.imageUrl != null && _pet.imageUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: ImageStorageService.isValidLocalFile(_pet.imageUrl)
                                  ? Image.file(File(_pet.imageUrl!), fit: BoxFit.cover)
                                  : Container(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      child: Icon(Icons.broken_image, size: 70, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Icon(Icons.pets, size: 80, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pet.species,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(_pet.breed),
                          const SizedBox(height: 4),
                          Text(_pet.detailedAge),
                          Text('Color: ${_pet.color}'),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  _pet.isNeutered ? Icons.check_circle : Icons.remove_circle_outline,
                                  size: 16,
                                  color: _pet.isNeutered
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _pet.isNeutered ? 'Esterilizado' : 'No esterilizado',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: const Icon(Icons.calendar_month, size: 28, color: CategoryColors.agenda),
                  title: const Text('Eventos', style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CalendarScreen(pet: _pet)),
                    );
                  },
                ),
              ),
            ),

            // ✅ NUEVO: Microchip card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.numbers, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Microchip', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              microchipText,
                              style: TextStyle(
                                color: microchipHasValue ? null : Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (microchipHasValue)
                        IconButton(
                          tooltip: 'Copiar',
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _pet.microchipNumber!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Microchip copiado')),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),

            const Divider(),
            for (final group in featureGroupOrder)
              if (features.any((feature) => feature['group'] == group))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0, bottom: 8.0, left: 4.0),
                        child: Text(
                          group,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      GridView(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: crossAxisSpacing,
                          mainAxisSpacing: mainAxisSpacing,
                          mainAxisExtent: featureCardHeight,
                        ),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: features.where((feature) => feature['group'] == group).map((feature) {
                          return _buildFeatureCard(
                            context,
                            title: feature['title'],
                            icon: feature['icon'],
                            color: feature['color'],
                            onTap: feature['onTap'],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 16.0),
          ],
        ),
      ),
    );
  }

  static const double _maxFeatureLabelScale = 1.3;
  static const double _minFeatureLabelScale = 0.5;
  static const TextStyle _featureLabelStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);

  TextScaler _featureLabelScaler(BuildContext context) =>
      MediaQuery.textScalerOf(context).clamp(maxScaleFactor: _maxFeatureLabelScale);

  // Escala máxima con la que la palabra más larga cabe en una línea, para no
  // partir palabras a mitad (p. ej. "Desparasitaciones") con fuente grande.
  // Se mide con la escala candidata, porque el ancho no siempre es lineal.
  TextScaler _fittingLabelScaler(BuildContext context, String title, double maxWidth) {
    final wanted = _featureLabelScaler(context).scale(1);
    var factor = wanted;

    double longestWordWidth(double scale) {
      var longest = 0.0;
      for (final word in title.split(' ')) {
        final painter = TextPainter(
          text: TextSpan(text: word, style: _featureLabelStyle),
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.linear(scale),
        )..layout();
        if (painter.width > longest) longest = painter.width;
      }
      return longest;
    }

    while (factor > _minFeatureLabelScale && longestWordWidth(factor) > maxWidth * 0.9) {
      factor *= 0.95;
    }
    return TextScaler.linear(factor < _minFeatureLabelScale ? _minFeatureLabelScale : factor);
  }

  Widget _buildFeatureCard(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: color),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: LayoutBuilder(
                builder: (context, constraints) => Text(
                  title,
                  style: _featureLabelStyle.copyWith(color: Theme.of(context).colorScheme.onSurface),
                  textAlign: TextAlign.center,
                  textScaler: _fittingLabelScaler(context, title, constraints.maxWidth),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
