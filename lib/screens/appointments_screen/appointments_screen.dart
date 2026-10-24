import 'package:flutter/material.dart';
import 'package:pet_pal/theme/category_colors.dart';
import 'package:pet_pal/utils/layout_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/appointment.dart';
import 'package:pet_pal/providers/appointment_providers.dart';
import 'package:pet_pal/screens/add_edit_appointment_screen/add_edit_appointment_screen.dart';
import 'package:pet_pal/widgets/empty_state.dart';
import 'package:intl/intl.dart';

class AppointmentsScreen extends ConsumerWidget {
  final Pet pet;

  const AppointmentsScreen({super.key, required this.pet});

  Future<void> _deleteAppointment(
    BuildContext context,
    WidgetRef ref,
    Appointment appointment,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: const Text('¿Estás seguro de que quieres eliminar esta cita?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await ref.read(appointmentsProvider(pet.id).notifier).deleteAppointment(appointment);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cita eliminada con éxito.')),
      );
    } catch (e) {
      debugPrint('Error al eliminar la cita: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar la cita: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(appointmentsProvider(pet.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('Citas de ${pet.name}'),
      ),
      body: appointmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Error: $error')),
        data: (appointments) {
          if (appointments.isEmpty) {
            return EmptyState(
              icon: Icons.event_note,
              message: 'Aún no hay citas registradas para ${pet.name}.',
              actionHint: 'Presiona "+" para añadir una nueva.',
            );
          }

          return ListView.builder(
            itemCount: appointments.length,
            padding: kFabListPadding,
            itemBuilder: (context, index) {
              final appointment = appointments[index];
              return Dismissible(
                key: ValueKey(appointment.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Theme.of(context).colorScheme.error,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
                ),
                confirmDismiss: (_) async {
                  await _deleteAppointment(context, ref, appointment);
                  return false;
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today, color: CategoryColors.agenda),
                    title: Text(
                      appointment.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: appointment.isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    subtitle: Text(
                      '${DateFormat('dd/MM/yyyy HH:mm').format(appointment.dateTime)}\n'
                      '${appointment.location ?? 'Sin lugar'}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        decoration: appointment.isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (appointment.isCompleted)
                          const Icon(Icons.check_circle, color: Colors.green),
                        IconButton(
                          icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
                          tooltip: 'Editar',
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddEditAppointmentScreen(
                                  petId: pet.id,
                                  appointment: appointment,
                                ),
                              ),
                            );
                            // No hace falta refrescar acá: si se guardó algo,
                            // AppointmentsNotifier.addAppointment/
                            // updateAppointment ya refrescó el estado
                            // internamente antes de volver; si se canceló, no
                            // hay nada que refrescar.
                          },
                        ),
                      ],
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddEditAppointmentScreen(
                            petId: pet.id,
                            appointment: appointment,
                          ),
                        ),
                      );
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
              builder: (context) => AddEditAppointmentScreen(petId: pet.id),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
