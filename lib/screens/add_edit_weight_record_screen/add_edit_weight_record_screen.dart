import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pet_pal/models/weight_record.dart';
import 'package:pet_pal/providers/weight_record_providers.dart';

class AddEditWeightRecordScreen extends ConsumerStatefulWidget {
  final String petId;
  final WeightRecord? weightRecord;

  const AddEditWeightRecordScreen({super.key, required this.petId, this.weightRecord});

  @override
  ConsumerState<AddEditWeightRecordScreen> createState() => _AddEditWeightRecordScreenState();
}

class _AddEditWeightRecordScreenState extends ConsumerState<AddEditWeightRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  DateTime _date = DateTime.now();

  bool get _isEditing => widget.weightRecord != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _weightController.text = widget.weightRecord!.weight.toString();
      _date = widget.weightRecord!.date;
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _date) {
      setState(() {
        _date = picked;
      });
    }
  }

  void _saveWeightRecord() async {
    if (_formKey.currentState!.validate()) {
      final repository = ref.read(weightRecordRepositoryProvider);
      final int? id = _isEditing ? widget.weightRecord!.id : null; // <-- CORREGIDO: Ahora el ID es opcional (nullable)

      final newWeightRecord = WeightRecord(
        id: id,
        petId: widget.petId,
        weight: double.parse(_weightController.text),
        date: _date,
      );

      try {
        if (_isEditing) {
          await repository.updateWeightRecord(newWeightRecord);
        } else {
          await repository.insertWeightRecord(newWeightRecord);
        }

        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        debugPrint('Error al guardar el registro de peso: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar el registro de peso: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Peso' : 'Añadir Nuevo Peso'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(
                  labelText: 'Peso (en kg)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.monitor_weight),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, introduce el peso.';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Por favor, introduce un número válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text('Fecha: ${DateFormat('dd/MM/yyyy').format(_date)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _saveWeightRecord,
                icon: const Icon(Icons.save),
                label: Text(_isEditing ? 'Actualizar Peso' : 'Guardar Peso'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
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