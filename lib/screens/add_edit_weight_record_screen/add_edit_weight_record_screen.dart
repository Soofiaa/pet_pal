import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_pal/models/weight_record.dart';
import 'package:pet_pal/data/database_helper.dart';

class AddEditWeightRecordScreen extends StatefulWidget {
  final String petId;
  final WeightRecord? weightRecord;

  const AddEditWeightRecordScreen({super.key, required this.petId, this.weightRecord});

  @override
  State<AddEditWeightRecordScreen> createState() => _AddEditWeightRecordScreenState();
}

class _AddEditWeightRecordScreenState extends State<AddEditWeightRecordScreen> {
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
      final dbHelper = DatabaseHelper();
      final int? id = _isEditing ? widget.weightRecord!.id : null; // <-- CORREGIDO: Ahora el ID es opcional (nullable)

      final newWeightRecord = WeightRecord(
        id: id,
        petId: widget.petId,
        weight: double.parse(_weightController.text),
        date: _date,
      );

      if (_isEditing) {
        await dbHelper.updateWeightRecord(newWeightRecord);
      } else {
        await dbHelper.insertWeightRecord(newWeightRecord);
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