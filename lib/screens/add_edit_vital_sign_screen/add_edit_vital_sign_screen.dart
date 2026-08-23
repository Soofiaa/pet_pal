import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pet_pal/models/vital_sign_config.dart';
import 'package:pet_pal/models/vital_sign_record.dart';
import 'package:pet_pal/providers/vital_sign_providers.dart';

/// Entrada rápida de un signo vital: solo valor + fecha (por defecto ahora),
/// para mínima fricción en mediciones frecuentes. Ver BACKLOG.md ítem 4.
class AddEditVitalSignScreen extends ConsumerStatefulWidget {
  final String petId;
  final VitalSignType type;
  final VitalSignRecord? vitalSignRecord;

  const AddEditVitalSignScreen({
    super.key,
    required this.petId,
    required this.type,
    this.vitalSignRecord,
  });

  @override
  ConsumerState<AddEditVitalSignScreen> createState() =>
      _AddEditVitalSignScreenState();
}

class _AddEditVitalSignScreenState
    extends ConsumerState<AddEditVitalSignScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _isSaving = false;

  bool get _isEditing => widget.vitalSignRecord != null;

  VitalSignConfig get _config => vitalSignConfigs[widget.type]!;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _valueController.text = widget.vitalSignRecord!.value.toString();
      _date = widget.vitalSignRecord!.date;
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
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

  Future<void> _save() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa los campos marcados en rojo antes de guardar.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final notifier =
        ref.read(vitalSignRecordsProvider(widget.petId).notifier);
    final record = VitalSignRecord(
      id: _isEditing ? widget.vitalSignRecord!.id : null,
      petId: widget.petId,
      type: widget.type,
      value: double.parse(_valueController.text),
      date: _date,
    );

    try {
      if (_isEditing) {
        await notifier.updateVitalSignRecord(record);
      } else {
        await notifier.addVitalSignRecord(record);
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error al guardar el registro de ${_config.label.toLowerCase()}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar el registro de ${_config.label.toLowerCase()}: $e')),
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
        title: Text(_isEditing ? 'Editar ${_config.label}' : 'Añadir ${_config.label}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _valueController,
                autofocus: !_isEditing,
                decoration: InputDecoration(
                  labelText: '${_config.label} (${_config.unit})',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(_config.icon),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, introduce un valor.';
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
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isEditing ? 'Actualizar' : 'Guardar'),
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
