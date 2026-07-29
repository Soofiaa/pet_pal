// ignore_for_file: use_build_context_synchronously, duplicate_ignore

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/medication.dart';
import 'package:pet_pal/providers/medication_providers.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class AddEditMedicationScreen extends ConsumerStatefulWidget {
  final Pet pet;
  final Medication? medication;

  const AddEditMedicationScreen({super.key, required this.pet, this.medication});

  @override
  ConsumerState<AddEditMedicationScreen> createState() => _AddEditMedicationScreenState();
}

class _AddEditMedicationScreenState extends ConsumerState<AddEditMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  int _timesPerDay = 1;
  List<String> _reminderTimes = ['09:00'];

  @override
  void initState() {
    super.initState();
    if (widget.medication != null) {
      // Si estamos editando, precargamos los datos
      _nameController.text = widget.medication!.name;
      _dosageController.text = widget.medication!.dosage;
      _frequencyController.text = widget.medication!.frequency;
      _notesController.text = widget.medication!.notes;
      _startDate = widget.medication!.startDate;
      _endDate = widget.medication!.endDate;
      if (widget.medication!.reminderTimes.isNotEmpty) {
        _reminderTimes = List<String>.from(widget.medication!.reminderTimes);
        _timesPerDay = _reminderTimes.length;
      }
    }
  }

  TimeOfDay _parseTimeOfDay(String value) {
    final parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTimeOfDay(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  void _setTimesPerDay(int value) {
    setState(() {
      _timesPerDay = value;
      if (_reminderTimes.length < value) {
        _reminderTimes = List<String>.from(_reminderTimes)
          ..addAll(List.generate(
              value - _reminderTimes.length, (_) => '09:00'));
      } else if (_reminderTimes.length > value) {
        _reminderTimes = _reminderTimes.sublist(0, value);
      }
    });
  }

  Future<void> _pickReminderTime(int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _parseTimeOfDay(_reminderTimes[index]),
    );
    if (picked != null) {
      setState(() {
        _reminderTimes[index] = _formatTimeOfDay(picked);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _saveMedication() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Si la fecha de fin es anterior a la de inicio, ajusta el orden.
      if (_endDate != null && _endDate!.isBefore(_startDate)) {
        setState(() {
          final temp = _startDate;
          _startDate = _endDate!;
          _endDate = temp;
        });
      }

      final newMedication = Medication(
        id: widget.medication?.id ?? const Uuid().v4(),
        petId: widget.pet.id,
        name: _nameController.text,
        dosage: _dosageController.text,
        frequency: _frequencyController.text,
        notes: _notesController.text,
        startDate: _startDate,
        endDate: _endDate,
        reminderTimes: _reminderTimes,
      );

      final notifier = ref.read(medicationsProvider(widget.pet.id).notifier);

      if (widget.medication == null) {
        await notifier.addMedication(newMedication);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Medicación agregada con éxito.')),
          );
        }
      } else {
        await notifier.updateMedication(widget.medication!, newMedication);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Medicación actualizada con éxito.')),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.medication == null ? 'Añadir Medicación' : 'Editar Medicación'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre de la medicación'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, introduce el nombre de la medicación';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _dosageController,
                decoration: const InputDecoration(labelText: 'Dosis'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, introduce la dosis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _frequencyController,
                decoration: const InputDecoration(
                  labelText: 'Notas de frecuencia (opcional, ej. "con comida", "en ayunas")',
                ),
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notas (opcional)'),
                maxLines: 3,
              ),
              const SizedBox(height: 24.0),
              Text('Fecha de Inicio:', style: Theme.of(context).textTheme.titleMedium),
              ListTile(
                title: Text(DateFormat('dd/MM/yyyy').format(_startDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context, true),
              ),
              const SizedBox(height: 16.0),
              Text('Fecha de Fin (opcional):', style: Theme.of(context).textTheme.titleMedium),
              ListTile(
                title: Text(_endDate == null ? 'No especificada' : DateFormat('dd/MM/yyyy').format(_endDate!)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context, false),
              ),
              const SizedBox(height: 24.0),
              Text('Veces al día:', style: Theme.of(context).textTheme.titleMedium),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _timesPerDay > 1
                        ? () => _setTimesPerDay(_timesPerDay - 1)
                        : null,
                  ),
                  Text(
                    '$_timesPerDay',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _timesPerDay < 6
                        ? () => _setTimesPerDay(_timesPerDay + 1)
                        : null,
                  ),
                ],
              ),
              Text('Horarios de toma:', style: Theme.of(context).textTheme.titleMedium),
              ...List.generate(_timesPerDay, (index) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: Text('Horario ${index + 1}'),
                  trailing: Text(
                    _reminderTimes[index],
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () => _pickReminderTime(index),
                );
              }),
              const SizedBox(height: 32.0),
              ElevatedButton.icon(
                onPressed: _saveMedication,
                icon: const Icon(Icons.save),
                label: Text(widget.medication == null ? 'Guardar' : 'Actualizar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
