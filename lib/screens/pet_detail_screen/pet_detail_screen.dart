import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/screens/add_edit_pet_screen/add_edit_pet_screen.dart';
import 'package:pet_pal/screens/vaccinations_screen/vaccinations_screen.dart';
import 'package:pet_pal/screens/appointments_screen/appointments_screen.dart';
import 'package:pet_pal/screens/weight_record_screen/weight_record_screen.dart';
import 'package:pet_pal/screens/food_allergy_screen/food_allergy_screen.dart';
import 'package:pet_pal/screens/notes_screen/notes_screen.dart';
import 'package:pet_pal/screens/calendar_screen/calendar_screen.dart';
import 'package:pet_pal/screens/deworming_screen/deworming_screen.dart';
import 'package:pet_pal/screens/medications_screen/medications_screen.dart';

class PetDetailScreen extends StatefulWidget {
  final Pet pet;

  const PetDetailScreen({super.key, required this.pet});

  @override
  State<PetDetailScreen> createState() => _PetDetailScreenState();
}

class _PetDetailScreenState extends State<PetDetailScreen> {
  late Pet _pet;

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

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> features = [
      {
        'title': 'Alergias',
        'icon': Icons.warning_amber,
        'color': Colors.amber,
        'onTap': () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => FoodAllergyScreen(pet: _pet)));
        },
      },
      {
        'title': 'Citas',
        'icon': Icons.event,
        'color': Colors.deepOrange,
        'onTap': () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => AppointmentsScreen(pet: _pet)));
        },
      },
      {
        'title': 'Desparasitaciones',
        'icon': Icons.medication,
        'color': Colors.orange,
        'onTap': () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => DewormingScreen(pet: _pet)));
        },
      },
      {
        'title': 'Medicación',
        'icon': Icons.medication_liquid,
        'color': Colors.blueGrey,
        'onTap': () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => MedicationsScreen(pet: _pet)));
        },
      },
      {
        'title': 'Notas',
        'icon': Icons.note,
        'color': Colors.teal,
        'onTap': () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => NotesScreen(pet: _pet)));
        },
      },
      {
        'title': 'Peso',
        'icon': Icons.monitor_weight,
        'color': Colors.purple,
        'onTap': () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => WeightRecordScreen(pet: _pet)));
        },
      },
      {
        'title': 'Vacunas',
        'icon': Icons.vaccines,
        'color': Colors.green,
        'onTap': () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => VaccinationsScreen(pet: _pet)));
        },
      },
    ];

    features.sort((a, b) => (a['title'] as String).compareTo(b['title'] as String));

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
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: _pet.imageUrl != null && _pet.imageUrl!.isNotEmpty
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: File(_pet.imageUrl!).existsSync()
                          ? Image.file(File(_pet.imageUrl!), fit: BoxFit.cover)
                          : const Icon(Icons.pets, size: 80, color: Colors.grey),
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
                  const Spacer(),
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
                                color: microchipHasValue ? Colors.black : Colors.grey,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: crossAxisSpacing,
                mainAxisSpacing: mainAxisSpacing,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: features.map((feature) {
                  return _buildFeatureCard(
                    context,
                    title: feature['title'],
                    icon: feature['icon'],
                    color: feature['color'],
                    onTap: feature['onTap'],
                  );
                }).toList(),
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
