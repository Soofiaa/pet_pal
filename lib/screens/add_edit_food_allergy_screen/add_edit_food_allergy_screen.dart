import 'package:flutter/material.dart';
import 'package:pet_pal/models/food_allergy.dart';
import 'package:pet_pal/data/database_helper.dart';
import 'package:intl/intl.dart';

class AddEditFoodAllergyScreen extends StatefulWidget {
  final String petId;
  final FoodAllergy? foodAllergy;

  const AddEditFoodAllergyScreen({
    super.key,
    required this.petId,
    this.foodAllergy,
  });

  @override
  State<AddEditFoodAllergyScreen> createState() => _AddEditFoodAllergyScreenState();
}

class _AddEditFoodAllergyScreenState extends State<AddEditFoodAllergyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _allergyController = TextEditingController();
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    if (widget.foodAllergy != null) {
      // Modo de edición: precarga los datos existentes
      _allergyController.text = widget.foodAllergy!.food;
      _selectedDate = widget.foodAllergy!.dateRecorded;
    } else {
      // Modo de añadir: usa la fecha actual por defecto
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _allergyController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveAllergy() async {
    if (_formKey.currentState!.validate()) {
      final dbHelper = DatabaseHelper();
      final newAllergy = FoodAllergy(
        id: widget.foodAllergy?.id, // Conserva el ID si es una edición
        petId: widget.petId,
        food: _allergyController.text,
        dateRecorded: _selectedDate,
      );

      if (widget.foodAllergy == null) {
        // Añadir nueva alergia
        await dbHelper.insertFoodAllergy(newAllergy);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Alergia alimentaria añadida con éxito.')),
          );
        }
      } else {
        // Actualizar alergia existente
        await dbHelper.updateFoodAllergy(newAllergy);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Alergia alimentaria actualizada con éxito.')),
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
        title: Text(widget.foodAllergy == null ? 'Añadir Alergia' : 'Editar Alergia'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _allergyController,
                decoration: const InputDecoration(
                  labelText: 'Alimento Alergénico',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.warning_amber),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, introduce el alimento alergénico.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Fecha de Registro',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                controller: TextEditingController(
                  text: DateFormat('dd/MM/yyyy').format(_selectedDate),
                ),
                onTap: () => _selectDate(context),
              ),
              const SizedBox(height: 24.0),
              ElevatedButton.icon(
                onPressed: _saveAllergy,
                icon: const Icon(Icons.save),
                label: Text(widget.foodAllergy == null ? 'Guardar Alergia' : 'Actualizar Alergia'),
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