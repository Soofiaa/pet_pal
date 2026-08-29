import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/food_allergy.dart';
import 'package:pet_pal/providers/food_allergy_providers.dart';
import 'package:pet_pal/screens/add_edit_food_allergy_screen/add_edit_food_allergy_screen.dart';
import 'package:pet_pal/widgets/empty_state.dart';
import 'package:intl/intl.dart';

class FoodAllergyScreen extends ConsumerWidget {
  final Pet pet;

  const FoodAllergyScreen({super.key, required this.pet});

  Future<void> _deleteFoodAllergy(
    BuildContext context,
    WidgetRef ref,
    FoodAllergy foodAllergy,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: const Text('¿Estás seguro de que quieres eliminar esta alergia alimentaria?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await ref.read(foodAllergiesProvider(pet.id).notifier).deleteFoodAllergy(foodAllergy.id!);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alergia alimentaria eliminada con éxito.')),
      );
    } catch (e) {
      debugPrint('Error al eliminar la alergia alimentaria: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar la alergia alimentaria: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foodAllergiesAsync = ref.watch(foodAllergiesProvider(pet.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('Alergias de ${pet.name}'),
      ),
      body: foodAllergiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Error: $error')),
        data: (foodAllergies) {
          if (foodAllergies.isEmpty) {
            return EmptyState(
              icon: Icons.warning_amber_rounded,
              message: 'Aún no hay alergias alimentarias registradas para ${pet.name}.',
              actionHint: 'Presiona "+" para añadir una nueva.',
            );
          }

          return ListView.builder(
            itemCount: foodAllergies.length,
            itemBuilder: (context, index) {
              final allergy = foodAllergies[index];
              return Dismissible(
                key: Key(allergy.id.toString()),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  await _deleteFoodAllergy(context, ref, allergy);
                  return null;
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber, color: Colors.amber),
                    title: Text(
                      allergy.food,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Registrada el ${DateFormat('dd/MM/yyyy').format(allergy.dateRecorded)}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddEditFoodAllergyScreen(
                            petId: pet.id,
                            foodAllergy: allergy,
                          ),
                        ),
                      );
                      // No hace falta refrescar acá: si se guardó algo,
                      // FoodAllergiesNotifier.addFoodAllergy/
                      // updateFoodAllergy ya refrescó el estado
                      // internamente antes de volver; si se canceló, no
                      // hay nada que refrescar.
                    },
                  ),
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
              builder: (context) => AddEditFoodAllergyScreen(petId: pet.id),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
