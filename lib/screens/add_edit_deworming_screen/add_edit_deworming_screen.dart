import 'package:flutter/material.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/deworming.dart';
import 'package:pet_pal/data/database_helper.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class AddEditDewormingScreen extends StatefulWidget {
  final Pet pet;
  final Deworming? deworming;

  const AddEditDewormingScreen({
    super.key,
    required this.pet,
    this.deworming,
  });

  @override
  State<AddEditDewormingScreen> createState() => _AddEditDewormingScreenState();
}

class _AddEditDewormingScreenState extends State<AddEditDewormingScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _productController;
  late TextEditingController _dateController;
  late TextEditingController _nextDateController;

  Deworming? _currentDeworming;
  List<String> _productSuggestions = [];

  @override
  void initState() {
    super.initState();
    _currentDeworming = widget.deworming;
    _productController = TextEditingController(text: _currentDeworming?.product ?? '');
    _dateController = TextEditingController(
      text: _currentDeworming != null
          ? DateFormat('dd/MM/yyyy').format(_currentDeworming!.date)
          : '',
    );
    _nextDateController = TextEditingController(
      text: _currentDeworming?.nextDate != null
          ? DateFormat('dd/MM/yyyy').format(_currentDeworming!.nextDate!)
          : '',
    );

    _loadProductSuggestions();
  }

  @override
  void dispose() {
    _productController.dispose();
    _dateController.dispose();
    _nextDateController.dispose();
    super.dispose();
  }

  Future<void> _loadProductSuggestions() async {
    final names = await DatabaseHelper().getDewormingProductNames();

    if (!mounted) return;

    setState(() {
      _productSuggestions = names;
    });
  }

  Future<void> _saveDeworming() async {
    if (_formKey.currentState!.validate()) {
      final newDeworming = Deworming(
        id: _currentDeworming?.id ?? const Uuid().v4(),
        petId: widget.pet.id,
        product: _productController.text,
        date: DateFormat('dd/MM/yyyy').parse(_dateController.text),
        nextDate: _nextDateController.text.isNotEmpty
            ? DateFormat('dd/MM/yyyy').parse(_nextDateController.text)
            : null,
      );

      if (_currentDeworming == null) {
        await DatabaseHelper().insertDeworming(newDeworming);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Desparasitación agregada con éxito.')),
          );
        }
      } else {
        await DatabaseHelper().updateDeworming(newDeworming);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Desparasitación actualizada con éxito.')),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      controller.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deworming == null ? 'Añadir Desparasitación' : 'Editar Desparasitación'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _productController.text),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  final query = textEditingValue.text.trim().toLowerCase();

                  if (query.isEmpty) {
                    return _productSuggestions;
                  }

                  return _productSuggestions.where((option) {
                    return option.toLowerCase().contains(query);
                  });
                },
                onSelected: (String selection) {
                  _productController.text = selection;
                },
                fieldViewBuilder: (
                    context,
                    textEditingController,
                    focusNode,
                    onFieldSubmitted,
                    ) {
                  return TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Producto/Medicina',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.vaccines),
                    ),
                    onChanged: (value) {
                      _productController.text = value;
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor, ingresa el nombre del producto.';
                      }
                      return null;
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Fecha de la Desparasitación',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () => _selectDate(context, _dateController),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, selecciona una fecha.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nextDateController,
                decoration: const InputDecoration(
                  labelText: 'Próxima Fecha (Opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.next_plan),
                ),
                readOnly: true,
                onTap: () => _selectDate(context, _nextDateController),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _saveDeworming,
                icon: const Icon(Icons.save),
                label: Text(widget.deworming == null ? 'Guardar' : 'Actualizar'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}