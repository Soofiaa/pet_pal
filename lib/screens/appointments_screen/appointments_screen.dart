import 'package:flutter/material.dart';
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
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
            itemBuilder: (context, index) {
              final appointment = appointments[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.calendar_today, color: Colors.blueAccent),
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
                      color: Colors.grey,
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
                        icon: const Icon(Icons.edit, color: Colors.blue),
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
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteAppointment(context, ref, appointment),
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
