import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/food_record.dart';
import 'package:pet_pal/providers/food_record_providers.dart';
import 'package:pet_pal/screens/add_edit_food_record_screen/add_edit_food_record_screen.dart';
import 'package:pet_pal/widgets/empty_state.dart';
import 'package:intl/intl.dart';

class FoodRecordScreen extends ConsumerWidget {
  final Pet pet;

  const FoodRecordScreen({super.key, required this.pet});

  Future<void> _deleteFoodRecord(
    BuildContext context,
    WidgetRef ref,
    FoodRecord foodRecord,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: const Text('¿Estás seguro de que quieres eliminar este registro de alimento?'),
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
      await ref.read(foodRecordsProvider(pet.id).notifier).deleteFoodRecord(foodRecord.id!);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro de alimento eliminado con éxito.')),
      );
    } catch (e) {
      debugPrint('Error al eliminar el registro de alimento: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar el registro de alimento: $e')),
      );
    }
  }

  String _subtitleFor(FoodRecord record) {
    final String range = record.startDate != null
        ? '${DateFormat('dd/MM/yyyy').format(record.startDate!)} - '
            '${record.isOngoing ? "Sigue comiendo" : DateFormat('dd/MM/yyyy').format(record.endDate!)}'
        : (record.isOngoing ? 'Sigue comiendo' : 'Hasta ${DateFormat('dd/MM/yyyy').format(record.endDate!)}');
    return record.notes.isEmpty ? range : '$range · ${record.notes}';
  }

  Widget _buildCard(BuildContext context, WidgetRef ref, FoodRecord record) {
    return Dismissible(
      key: Key(record.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        await _deleteFoodRecord(context, ref, record);
        return null;
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: ListTile(
          leading: const Icon(Icons.restaurant, color: Colors.lightGreen),
          title: Text(
            record.foodName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(_subtitleFor(record), style: const TextStyle(color: Colors.grey)),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddEditFoodRecordScreen(
                  petId: pet.id,
                  foodRecord: record,
                ),
              ),
            );
            // No hace falta refrescar acá: si se guardó algo,
            // FoodRecordsNotifier.addFoodRecord/updateFoodRecord ya
            // refrescó el estado internamente antes de volver; si se
            // canceló, no hay nada que refrescar.
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foodRecordsAsync = ref.watch(foodRecordsProvider(pet.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('Alimentos de ${pet.name}'),
      ),
      body: foodRecordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Error: $error')),
        data: (foodRecords) {
          if (foodRecords.isEmpty) {
            return EmptyState(
              icon: Icons.restaurant,
              message: 'Aún no hay historial de alimentos registrado para ${pet.name}.',
              actionHint: 'Presiona "+" para añadir uno nuevo.',
            );
          }

          // Con fecha de inicio primero (más reciente primero); los que no
          // la tienen van aparte al final, en el orden en que llegaron del
          // repository -no hay fecha por la que ordenarlos-.
          final withStartDate = foodRecords.where((r) => r.startDate != null).toList()
            ..sort((a, b) => b.startDate!.compareTo(a.startDate!));
          final withoutStartDate = foodRecords.where((r) => r.startDate == null).toList();

          return ListView(
            children: [
              for (final record in withStartDate) _buildCard(context, ref, record),
              if (withoutStartDate.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Fecha de inicio desconocida',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                  ),
                ),
                for (final record in withoutStartDate) _buildCard(context, ref, record),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEditFoodRecordScreen(petId: pet.id),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
