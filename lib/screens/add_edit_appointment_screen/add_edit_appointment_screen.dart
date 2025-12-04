import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:pet_pal/models/appointment.dart';
import 'package:pet_pal/data/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:pet_pal/services/notification_service.dart';

class AddEditAppointmentScreen extends StatefulWidget {
  final String petId;
  final Appointment? appointment;

  const AddEditAppointmentScreen({super.key, required this.petId, this.appointment});

  @override
  State<AddEditAppointmentScreen> createState() => _AddEditAppointmentScreenState();
}

class _AddEditAppointmentScreenState extends State<AddEditAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _typeController = TextEditingController();
  late DateTime _selectedDateTime;

  @override
  void initState() {
    super.initState();
    if (widget.appointment != null) {
      _titleController.text = widget.appointment!.title;
      _selectedDateTime = widget.appointment!.dateTime;
      _descriptionController.text = widget.appointment!.description ?? '';
      _locationController.text = widget.appointment!.location ?? '';
      _typeController.text = widget.appointment!.type ?? '';
    } else {
      _selectedDateTime = DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDateTime) {
      setState(() {
        _selectedDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDateTime.hour,
          _selectedDateTime.minute,
        );
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime.year,
          _selectedDateTime.month,
          _selectedDateTime.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  void _searchLocation() async {
    final String? query = await showDialog<String>(
      context: context,
      builder: (context) {
        final TextEditingController controller = TextEditingController();
        return AlertDialog(
          title: const Text('Buscar Ubicación'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Introduce un lugar'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Buscar'),
            ),
          ],
        );
      },
    );

    if (query != null && query.isNotEmpty) {
      setState(() {
        _locationController.text = 'Clínica Veterinaria "$query"';
      });
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ubicación actualizada con el lugar buscado.')),
        );
      }
    }
  }

  Future<void> _saveAppointment() async {
    if (_formKey.currentState!.validate()) {
      final dbHelper = DatabaseHelper();
      final String id = widget.appointment?.id ?? const Uuid().v4();
      final bool isCompleted = widget.appointment?.isCompleted ?? false;

      final newAppointment = Appointment(
        id: id,
        petId: widget.petId,
        dateTime: _selectedDateTime,
        title: _titleController.text,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        location: _locationController.text.isEmpty ? null : _locationController.text,
        type: _typeController.text.isEmpty ? null : _typeController.text,
        isCompleted: isCompleted, // Se mantiene el estado de completado si se está editando
      );

      // Lógica para programar notificación un día antes
      final notificationDateTime = _selectedDateTime.subtract(const Duration(days: 1));

      // Si se está editando una cita, cancela la notificación anterior
      if (widget.appointment != null) {
        await NotificationService().cancelNotification(widget.appointment!.id.hashCode);
      }

      // Si la fecha de la notificación no está en el pasado, la programamos.
      if (notificationDateTime.isAfter(DateTime.now())) {
        await NotificationService().scheduleNotification(
          id: id.hashCode,
          title: 'Recordatorio de Cita: ${_titleController.text}',
          body: 'Tu cita es mañana a las ${DateFormat('HH:mm').format(_selectedDateTime)}.',
          scheduledDateTime: notificationDateTime,
          payload: id,
        );
      }

      if (widget.appointment == null) {
        await dbHelper.insertAppointment(newAppointment);
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cita añadida con éxito.')),
          );
        }
      } else {
        await dbHelper.updateAppointment(newAppointment);
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cita actualizada con éxito.')),
          );
        }
      }

      if(mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appointment == null ? 'Añadir Nueva Cita' : 'Editar Cita'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título de la Cita',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.event_note),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, introduce un título para la cita.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Fecha',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      readOnly: true,
                      controller: TextEditingController(
                        text: DateFormat('dd/MM/yyyy').format(_selectedDateTime),
                      ),
                      onTap: () => _selectDate(context),
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Hora',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      readOnly: true,
                      controller: TextEditingController(
                        text: DateFormat('HH:mm').format(_selectedDateTime),
                      ),
                      onTap: () => _selectTime(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (Opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Lugar (Opcional)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.location_on),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.map),
                    onPressed: _searchLocation,
                    tooltip: 'Buscar en el mapa',
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _typeController,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Cita (Opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_hospital),
                ),
              ),
              const SizedBox(height: 24.0),
              ElevatedButton.icon(
                onPressed: _saveAppointment,
                icon: const Icon(Icons.save),
                label: Text(widget.appointment == null ? 'Guardar Cita' : 'Actualizar Cita'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}