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

  // Se conserva siempre un DateTime "de trabajo" para cada picker, aunque
  // el switch correspondiente lo deje afuera del guardado -así el usuario
  // no pierde la fecha elegida si prende y apaga el switch por error-.
  late DateTime _startDate;
  late DateTime _endDate;
  late bool _startDateUnknown;
  late bool _isOngoing;
  bool _isSaving = false;

  bool get _isEditing => widget.foodRecord != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.foodRecord;
    if (existing != null) {
      _foodNameController.text = existing.foodName;
      _notesController.text = existing.notes;
      _startDateUnknown = existing.startDate == null;
      _startDate = existing.startDate ?? DateTime.now();
      _isOngoing = existing.isOngoing;
      _endDate = existing.endDate ?? DateTime.now();
    } else {
      _startDateUnknown = false;
      _startDate = DateTime.now();
      _isOngoing = true;
      _endDate = DateTime.now();
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
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _startDate) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _endDate) {
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
        startDate: _startDateUnknown ? null : _startDate,
        endDate: _isOngoing ? null : _endDate,
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('No recuerdo la fecha de inicio'),
                value: _startDateUnknown,
                onChanged: (value) => setState(() => _startDateUnknown = value),
              ),
              if (!_startDateUnknown) ...[
                const SizedBox(height: 8.0),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Fecha de Inicio',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  readOnly: true,
                  controller: TextEditingController(
                    text: DateFormat('dd/MM/yyyy').format(_startDate),
                  ),
                  onTap: () => _selectStartDate(context),
                ),
              ],
              const SizedBox(height: 16.0),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('¿Sigue comiendo este alimento?'),
                value: _isOngoing,
                onChanged: (value) => setState(() => _isOngoing = value),
              ),
              if (!_isOngoing) ...[
                const SizedBox(height: 8.0),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Fecha de Fin',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.event_busy),
                  ),
                  readOnly: true,
                  controller: TextEditingController(
                    text: DateFormat('dd/MM/yyyy').format(_endDate),
                  ),
                  onTap: () => _selectEndDate(context),
                ),
              ],
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
