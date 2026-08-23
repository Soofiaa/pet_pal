import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/deworming.dart';
import 'package:pet_pal/providers/deworming_providers.dart';
import '../add_edit_deworming_screen/add_edit_deworming_screen.dart';
import '../deworming_products_screen/deworming_products_screen.dart';
import 'package:intl/intl.dart';

class DewormingScreen extends ConsumerWidget {
  final Pet pet;

  const DewormingScreen({super.key, required this.pet});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Deworming deworming,
  ) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Desparasitación'),
        content: Text(
          '¿Estás seguro de que quieres eliminar la desparasitación "${deworming.product}" del ${DateFormat('dd/MM/yyyy').format(deworming.date)}?',
        ),
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
        await ref.read(dewormingsProvider(pet.id).notifier).deleteDeworming(deworming);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Desparasitación eliminada correctamente.')),
          );
        }
      } catch (e) {
        debugPrint('Error al eliminar la desparasitación: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar la desparasitación: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Deworming>> asyncDewormings =
        ref.watch(dewormingsProvider(pet.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('Desparasitaciones de ${pet.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Gestionar Productos',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DewormingProductsScreen()),
            ),
          ),
        ],
      ),
      body: asyncDewormings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Error: $error')),
        data: (dewormingList) {
          if (dewormingList.isEmpty) {
            return const Center(child: Text('No hay desparasitaciones registradas.'));
          }

          return ListView.builder(
            itemCount: dewormingList.length,
            itemBuilder: (context, index) {
              final deworming = dewormingList[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(deworming.product, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      if (deworming.isRecurring) ...[
                        const SizedBox(width: 6),
                        const Tooltip(
                          message: 'Recordatorio automático recurrente',
                          child: Icon(Icons.repeat, size: 16, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fecha: ${DateFormat('dd/MM/yyyy').format(deworming.date)}'),
                      if (deworming.effectiveNextDate() != null)
                        Text('Próxima fecha: ${DateFormat('dd/MM/yyyy').format(deworming.effectiveNextDate()!)}'),
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
                              builder: (context) => AddEditDewormingScreen(
                                pet: pet,
                                deworming: deworming,
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(context, ref, deworming),
                      ),
                    ],
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
              builder: (context) => AddEditDewormingScreen(pet: pet),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
