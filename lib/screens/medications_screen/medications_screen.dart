import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/medication.dart';
import 'package:pet_pal/providers/medication_providers.dart';
import 'package:pet_pal/screens/add_edit_medications_screen/add_edit_medications_screen.dart';
import 'package:pet_pal/widgets/empty_state.dart';
import 'package:intl/intl.dart';

class MedicationsScreen extends ConsumerWidget {
  final Pet pet;

  const MedicationsScreen({super.key, required this.pet});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Medication medication,
  ) async {
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
      try {
        await ref.read(medicationsProvider(pet.id).notifier).deleteMedication(medication);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Medicación eliminada correctamente.')),
          );
        }
      } catch (e) {
        debugPrint('Error al eliminar la medicación: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar la medicación: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Medication>> asyncMedications =
        ref.watch(medicationsProvider(pet.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('Medicación de ${pet.name}'),
      ),
      body: asyncMedications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Error: $error')),
        data: (medicationList) {
          if (medicationList.isEmpty) {
            return EmptyState(
              icon: Icons.medication,
              message: 'Aún no hay medicaciones registradas para ${pet.name}.',
              actionHint: 'Presiona "+" para añadir una nueva.',
            );
          }

          return ListView.builder(
            itemCount: medicationList.length,
            itemBuilder: (context, index) {
              final medication = medicationList[index];
              Future<void> goToEdit() async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddEditMedicationScreen(
                      pet: pet,
                      medication: medication,
                    ),
                  ),
                );
                // No hace falta refrescar acá: si se guardó algo,
                // MedicationsNotifier.addMedication/updateMedication ya
                // refrescó el estado internamente antes de volver; si se
                // canceló, no hay nada que refrescar.
              }

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(medication.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dosis: ${medication.dosage}'),
                          if (medication.frequency.isNotEmpty)
                            Text('Frecuencia: ${medication.frequency}'),
                          Text('Inicio: ${DateFormat('dd/MM/yyyy').format(medication.startDate)}'),
                          if (medication.endDate != null)
                            Text('Fin: ${DateFormat('dd/MM/yyyy').format(medication.endDate!)}'),
                          if (medication.reminderTimes.isNotEmpty)
                            Text('Horarios: ${medication.reminderTimes.join(', ')}'),
                          if (medication.notes.isNotEmpty)
                            Text('Notas: ${medication.notes}'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: goToEdit,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(context, ref, medication),
                          ),
                        ],
                      ),
                    ),
                    if (medication.reminderTimes.isEmpty)
                      InkWell(
                        onTap: goToEdit,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.schedule, color: Colors.amber.shade900),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Definí horarios exactos para recordatorios más precisos.',
                                  style: TextStyle(color: Colors.amber.shade900),
                                ),
                              ),
                              Icon(Icons.chevron_right, color: Colors.amber.shade900),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEditMedicationScreen(pet: pet),
            ),
          );
          // Mismo motivo que arriba: addMedication ya refresca internamente.
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
