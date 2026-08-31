import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/food_record.dart';
import 'package:pet_pal/providers/food_record_providers.dart';
import 'package:intl/intl.dart';

class AddEditFoodRecordScreen extends ConsumerStatefulWidget {
  final String petId;
  final FoodRecord? foodRecord;

  const AddEditFoodRecordScreen({
    super.key,
    required this.petId,
    this.foodRecord,
  });

  @override
  ConsumerState<AddEditFoodRecordScreen> createState() => _AddEditFoodRecordScreenState();
}

class _AddEditFoodRecordScreenState extends ConsumerState<AddEditFoodRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _foodNameController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSaving = false;

  bool get _isEditing => widget.foodRecord != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.foodRecord;
    if (existing != null) {
      _foodNameController.text = existing.foodName;
      _notesController.text = existing.notes;
      _startDate = existing.startDate;
      _endDate = existing.endDate;
    }
  }

  @override
  void dispose() {
    _foodNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _saveFoodRecord() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa los campos marcados en rojo antes de guardar.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final notifier = ref.read(foodRecordsProvider(widget.petId).notifier);
      final newRecord = FoodRecord(
        id: widget.foodRecord?.id,
        petId: widget.petId,
        foodName: _foodNameController.text,
        startDate: _startDate,
        endDate: _endDate,
        notes: _notesController.text,
      );

      if (_isEditing) {
        await notifier.updateFoodRecord(newRecord);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registro de alimento actualizado con éxito.')),
          );
        }
      } else {
        await notifier.addFoodRecord(newRecord);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registro de alimento añadido con éxito.')),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error al guardar el registro de alimento: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar el registro de alimento: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildDateField({
    required String label,
    required IconData icon,
    required DateTime? date,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        suffixIcon: date != null
            ? IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Borrar fecha',
                onPressed: onClear,
              )
            : null,
      ),
      readOnly: true,
      controller: TextEditingController(
        text: date != null ? DateFormat('dd/MM/yyyy').format(date) : 'Sin fecha',
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Registro de Alimento' : 'Añadir Registro de Alimento'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _foodNameController,
                decoration: const InputDecoration(
                  labelText: 'Alimento',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.restaurant),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, introduce el nombre del alimento.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              _buildDateField(
                label: 'Fecha de Inicio',
                icon: Icons.calendar_today,
                date: _startDate,
                onTap: () => _selectStartDate(context),
                onClear: () => setState(() => _startDate = null),
              ),
              const SizedBox(height: 16.0),
              _buildDateField(
                label: 'Fecha de Fin',
                icon: Icons.event_busy,
                date: _endDate,
                onTap: () => _selectEndDate(context),
                onClear: () => setState(() => _endDate = null),
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notas (reacciones, observaciones, etc.)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24.0),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveFoodRecord,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isEditing ? 'Actualizar Registro' : 'Guardar Registro'),
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
