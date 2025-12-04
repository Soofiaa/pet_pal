import 'package:flutter/material.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/medication.dart';
import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/screens/add_edit_medications_screen/add_edit_medications_screen.dart';
import 'package:intl/intl.dart';

class MedicationsScreen extends StatefulWidget {
  final Pet pet;

  const MedicationsScreen({super.key, required this.pet});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  late Future<List<Medication>> _medications;

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  void _loadMedications() {
    setState(() {
      _medications = DatabaseHelper().getMedicationsForPet(widget.pet.id);
    });
  }

  Future<void> _confirmDelete(Medication medication) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Medicación'),
        content: Text('¿Estás seguro de que quieres eliminar la medicación "${medication.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await DatabaseHelper().deleteMedication(medication.id!);
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medicación eliminada correctamente.')),
      );
      _loadMedications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Medicación de ${widget.pet.name}'),
      ),
      body: FutureBuilder<List<Medication>>(
        future: _medications,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay medicaciones registradas.'));
          } else {
            final medicationList = snapshot.data!;
            return ListView.builder(
              itemCount: medicationList.length,
              itemBuilder: (context, index) {
                final medication = medicationList[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: ListTile(
                    title: Text(medication.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dosis: ${medication.dosage}'),
                        Text('Frecuencia: ${medication.frequency}'),
                        Text('Inicio: ${DateFormat('dd/MM/yyyy').format(medication.startDate)}'),
                        if (medication.endDate != null)
                          Text('Fin: ${DateFormat('dd/MM/yyyy').format(medication.endDate!)}'),
                        if (medication.notes.isNotEmpty)
                          Text('Notas: ${medication.notes}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddEditMedicationScreen(
                                  pet: widget.pet,
                                  medication: medication,
                                ),
                              ),
                            );
                            _loadMedications();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDelete(medication),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEditMedicationScreen(pet: widget.pet),
            ),
          );
          _loadMedications();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}