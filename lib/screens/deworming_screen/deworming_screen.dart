import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/deworming.dart';
import 'package:pet_pal/providers/deworming_providers.dart';
import 'package:pet_pal/widgets/empty_state.dart';
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

  /// Banner de alerta cuando algún tipo de cobertura (interna/externa)
  /// nunca tuvo ni un solo registro en todo el historial de la mascota.
  /// Mismo patrón visual que la alerta de signos vitales fuera de rango
  /// (fondo rojo claro + ícono de advertencia), adaptado a un aviso de
  /// cabecera en vez de un indicador por registro, ya que acá el vacío es
  /// de toda la pantalla y no de un registro puntual.
  Widget _buildMissingCoverageBanner(Set<String> missingTypes) {
    if (missingTypes.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final type in missingTypes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nunca se ha registrado desparasitación $type para ${pet.name}.',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
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
          final missingCoverageTypes = Deworming.neverRecordedCoverageTypes(dewormingList);

          if (dewormingList.isEmpty) {
            return Column(
              children: [
                _buildMissingCoverageBanner(missingCoverageTypes),
                Expanded(
                  child: EmptyState(
                    icon: Icons.healing,
                    message: 'Aún no hay desparasitaciones registradas para ${pet.name}.',
                    actionHint: 'Presiona "+" para añadir una nueva.',
                  ),
                ),
              ],
            );
          }

          final idsWithVisibleNextDose = Deworming.idsWithVisibleNextDose(dewormingList);

          return Column(
            children: [
              _buildMissingCoverageBanner(missingCoverageTypes),
              Expanded(
                child: ListView.builder(
                  itemCount: dewormingList.length,
                  itemBuilder: (context, index) {
                    final deworming = dewormingList[index];
                    final bool showNextDose = deworming.id != null &&
                        idsWithVisibleNextDose.contains(deworming.id);
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
                            if (showNextDose && deworming.effectiveNextDate() != null)
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
                ),
              ),
            ],
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
