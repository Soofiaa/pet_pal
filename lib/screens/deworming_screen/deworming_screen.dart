import 'package:flutter/material.dart';
import 'package:pet_pal/utils/layout_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/deworming.dart';
import 'package:pet_pal/providers/deworming_providers.dart';
import 'package:pet_pal/widgets/empty_state.dart';
import '../vaccinations_screen/vaccinations_screen.dart' show isNextDoseOverdue;
import '../add_edit_deworming_screen/add_edit_deworming_screen.dart';
import '../deworming_products_screen/deworming_products_screen.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class DewormingScreen extends ConsumerWidget {
  final Pet pet;

  const DewormingScreen({super.key, required this.pet});

  /// Registro rápido: crea un registro NUEVO (no edita ni borra el vencido)
  /// copiando producto/tipo/frecuencia del registro vencido, con fecha de
  /// aplicación elegida y nextDate recalculada si es recurrente.
  Future<void> _registerQuickDeworming(
    BuildContext context,
    WidgetRef ref,
    Deworming deworming,
  ) async {
    final DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    var applicationDate = today;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final DateTime? nextDate =
              deworming.isRecurring &&
                      deworming.frequencyMonths != null &&
                      deworming.frequencyMonths! > 0
                  ? Deworming.addMonths(applicationDate, deworming.frequencyMonths!)
                  : null;

          return AlertDialog(
            title: const Text('Registrar aplicación'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Producto: ${deworming.product}'),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Fecha de aplicación'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(applicationDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: applicationDate,
                      firstDate: DateTime(2000),
                      lastDate: today,
                    );
                    if (picked != null) {
                      setState(() => applicationDate = picked);
                    }
                  },
                ),
                if (nextDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Próxima fecha: ${DateFormat('dd/MM/yyyy').format(nextDate)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirmar'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    final nextDate =
        deworming.isRecurring &&
                deworming.frequencyMonths != null &&
                deworming.frequencyMonths! > 0
            ? Deworming.addMonths(applicationDate, deworming.frequencyMonths!)
            : null;

    final newDeworming = Deworming(
      id: const Uuid().v4(),
      petId: deworming.petId,
      product: deworming.product,
      date: applicationDate,
      nextDate: nextDate,
      type: deworming.type,
      frequencyMonths: deworming.frequencyMonths,
      reminderDaysAhead: deworming.reminderDaysAhead,
      isRecurring: deworming.isRecurring,
    );

    try {
      await ref.read(dewormingsProvider(pet.id).notifier).addDeworming(newDeworming);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Desparasitación agregada con éxito.')),
        );
      }
    } catch (e) {
      debugPrint('Error al registrar la desparasitación rápida: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar la desparasitación: $e')),
        );
      }
    }
  }

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
  Widget _buildMissingCoverageBanner(BuildContext context, Set<String> missingTypes) {
    if (missingTypes.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.error),
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
                  Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nunca se ha registrado desparasitación $type para ${pet.name}.',
                      style: TextStyle(color: scheme.onErrorContainer, fontWeight: FontWeight.w600),
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
                _buildMissingCoverageBanner(context, missingCoverageTypes),
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
              _buildMissingCoverageBanner(context, missingCoverageTypes),
              Expanded(
                child: ListView.builder(
                  itemCount: dewormingList.length,
                  padding: kFabListPadding,
                  itemBuilder: (context, index) {
                    final deworming = dewormingList[index];
                    final bool showNextDose = deworming.id != null &&
                        idsWithVisibleNextDose.contains(deworming.id);
                    return Dismissible(
                      key: ValueKey(deworming.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Theme.of(context).colorScheme.error,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
                      ),
                      confirmDismiss: (_) async {
                        await _confirmDelete(context, ref, deworming);
                        return false;
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: ListTile(
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(deworming.product, style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              if (deworming.isRecurring) ...[
                                const SizedBox(width: 6),
                                Tooltip(
                                  message: 'Recordatorio automático recurrente',
                                  child: Icon(Icons.repeat, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Fecha: ${DateFormat('dd/MM/yyyy').format(deworming.date)}'),
                              if (showNextDose && deworming.effectiveNextDate() != null)
                                Builder(builder: (context) {
                                  final next = deworming.effectiveNextDate()!;
                                  final overdue = isNextDoseOverdue(next);
                                  final formatted = DateFormat('dd/MM/yyyy').format(next);
                                  return Text(
                                    overdue ? 'Vencida desde: $formatted' : 'Próxima fecha: $formatted',
                                    style: overdue
                                        ? TextStyle(
                                            color: Theme.of(context).colorScheme.error,
                                            fontWeight: FontWeight.w600,
                                          )
                                        : null,
                                  );
                                }),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showNextDose &&
                                  deworming.effectiveNextDate() != null &&
                                  isNextDoseOverdue(deworming.effectiveNextDate()!))
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  tooltip: 'Registrar aplicación',
                                  onPressed: () async {
                                    await _registerQuickDeworming(context, ref, deworming);
                                  },
                                ),
                              IconButton(
                                icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
                                tooltip: 'Editar',
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
                            ],
                          ),
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
