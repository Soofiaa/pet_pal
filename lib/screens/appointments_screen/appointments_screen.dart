import 'package:flutter/material.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/appointment.dart';
import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/screens/add_edit_appointment_screen/add_edit_appointment_screen.dart';
import 'package:intl/intl.dart';

class AppointmentsScreen extends StatefulWidget {
  final Pet pet;

  const AppointmentsScreen({super.key, required this.pet});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  List<Appointment> _appointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
    });

    final dbHelper = DatabaseHelper();
    final appointments = await dbHelper.getAppointmentsForPet(widget.pet.id);

    // NUEVA LÓGICA: Marcar citas pasadas como completadas
    final now = DateTime.now();
    for (var appointment in appointments) {
      if (!appointment.isCompleted && appointment.dateTime.isBefore(now)) {
        final completedAppointment = appointment.copyWith(isCompleted: true);
        await dbHelper.updateAppointment(completedAppointment);
      }
    }

    // Volver a cargar la lista después de actualizar
    final updatedAppointments = await dbHelper.getAppointmentsForPet(widget.pet.id);

    // Ordenar citas para mostrar las próximas primero
    updatedAppointments.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    setState(() {
      _appointments = updatedAppointments;
      _isLoading = false;
    });
  }

  Future<void> _deleteAppointment(Appointment appointment) async {
    final bool? confirm = await showDialog(
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

    if (confirm == true) {
      await DatabaseHelper().deleteAppointment(appointment.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cita eliminada con éxito.')),
        );
      }
      _loadAppointments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Citas de ${widget.pet.name}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _appointments.isEmpty
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No hay citas registradas para esta mascota.',
            style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
      )
          : ListView.builder(
        itemCount: _appointments.length,
        itemBuilder: (context, index) {
          final appointment = _appointments[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: ListTile(
              leading: const Icon(Icons.calendar_today, color: Colors.blueAccent),
              title: Text(
                appointment.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: appointment.isCompleted // Si está completada, se tacha el texto
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
              subtitle: Text(
                '${DateFormat('dd/MM/yyyy HH:mm').format(appointment.dateTime)}\n'
                    '${appointment.location ?? 'Sin lugar'}',
                style: TextStyle(
                  color: Colors.grey,
                  decoration: appointment.isCompleted // Si está completada, se tacha el texto
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
                            petId: widget.pet.id,
                            appointment: appointment,
                          ),
                        ),
                      );
                      _loadAppointments();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteAppointment(appointment),
                  ),
                ],
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddEditAppointmentScreen(
                      petId: widget.pet.id,
                      appointment: appointment,
                    ),
                  ),
                );
                _loadAppointments();
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEditAppointmentScreen(petId: widget.pet.id),
            ),
          );
          _loadAppointments();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}