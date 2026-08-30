import 'dart:io';
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
import 'package:pet_pal/screens/food_calculator_screen/food_calculator_screen.dart';
import 'package:pet_pal/models/vital_sign_config.dart';
import 'package:pet_pal/services/image_storage_service.dart';
import 'package:pet_pal/services/csv_export_service.dart';
import 'package:pet_pal/utils/entity_colors.dart';

class PetDetailScreen extends StatefulWidget {
  final Pet pet;

  const PetDetailScreen({super.key, required this.pet});

  @override
  State<PetDetailScreen> createState() => _PetDetailScreenState();
}

class _PetDetailScreenState extends State<PetDetailScreen> {
  late Pet _pet;
  bool _isGeneratingHealthSummary = false;
  bool _isGeneratingPetCard = false;
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

  Future<void> _generateAndShareHealthSummary() async {
    setState(() => _isGeneratingHealthSummary = true);

    try {
      final dbHelper = DatabaseHelper();
      final vaccinations = await dbHelper.getVaccinationsForPet(_pet.id);
      final medications = await dbHelper.getMedicationsForPet(_pet.id);
      final dewormings = await dbHelper.getDewormingsForPet(_pet.id);
      final weightRecords = await dbHelper.getWeightRecordsForPet(_pet.id);
      final documents = await dbHelper.getDocumentsForPet(_pet.id);
      final emergencyContacts = await dbHelper.getEmergencyContacts();
      final foodConfig = await dbHelper.getFoodConfigForPet(_pet.id);

      final pdfData = await PdfGenerator.generateHealthSummaryPdf(
        _pet,
        vaccinations: vaccinations,
        medications: medications,
        dewormings: dewormings,
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

  Future<void> _generateAndSharePetCard() async {
    setState(() => _isGeneratingPetCard = true);

    try {
      final dbHelper = DatabaseHelper();
      final vaccinations = await dbHelper.getVaccinationsForPet(_pet.id);
      final dewormings = await dbHelper.getDewormingsForPet(_pet.id);
      final foodAllergies = await dbHelper.getFoodAllergiesForPet(_pet.id);
      final weightRecords = await dbHelper.getWeightRecordsForPet(_pet.id);

      final pdfData = await PdfGenerator.generatePetCardPdf(
        _pet,
        vaccinations: vaccinations,
        dewormings: dewormings,
        foodAllergies: foodAllergies,
        weightRecords: weightRecords,
      );

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/carnet_${_pet.name}.pdf');
      await file.writeAsBytes(pdfData);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Carnet de ${_pet.name}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al generar el carnet.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPetCard = false);
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
      {
        'title': 'Calculadora Alimento',
        'icon': Icons.calculate,
        'color': entityColorFor('food_calculator'),
        'group': 'Otros',
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => FoodCalculatorScreen(pet: _pet)),
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
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Compartir ficha clínica',
              onPressed: _generateAndShareHealthSummary,
            ),
          if (_isGeneratingPetCard)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.badge),
              tooltip: 'Compartir carnet',
              onPressed: _generateAndSharePetCard,
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Exportar historial a CSV',
            onSelected: _exportCsvHistory,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'weight', child: Text('Historial de peso')),
              PopupMenuItem(value: 'vaccinations', child: Text('Historial de vacunas')),
              PopupMenuItem(value: 'medications', child: Text('Historial de medicación')),
              PopupMenuItem(value: 'deworming', child: Text('Historial de desparasitación')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.edit),
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
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.broken_image, size: 70, color: Colors.grey),
                                    ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Icon(Icons.pets, size: 80, color: Colors.grey),
                              ),
                            ),
                    ),
                  ),
                  const Spacer(),
                  Column(
                    children: [
                      SizedBox(
                        height: gridItemWidth,
                        width: gridItemWidth,
                        child: _buildFeatureCard(
                          context,
                          title: 'Eventos',
                          icon: Icons.calendar_month,
                          color: Colors.blue,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => CalendarScreen(pet: _pet)),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Chip(
                        label: Text(
                          _pet.isNeutered ? 'Esterilizado' : 'No esterilizado',
                          style: const TextStyle(fontSize: 10),
                        ),
                        avatar: Icon(
                          _pet.isNeutered ? Icons.check_circle : Icons.cancel,
                          size: 14,
                          color: _pet.isNeutered ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
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
                                color: microchipHasValue ? null : Colors.grey,
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
                      GridView.count(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: crossAxisSpacing,
                        mainAxisSpacing: mainAxisSpacing,
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
            Text(
              title,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
