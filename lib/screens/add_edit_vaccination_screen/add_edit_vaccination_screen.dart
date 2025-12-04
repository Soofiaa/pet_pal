import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:pet_pal/models/vaccination.dart';
import 'package:pet_pal/data/database_helper.dart';
import 'dart:io';

class AddEditVaccinationScreen extends StatefulWidget {
  final String petId;
  final Vaccination? vaccination;

  const AddEditVaccinationScreen({super.key, required this.petId, this.vaccination});

  @override
  State<AddEditVaccinationScreen> createState() => _AddEditVaccinationScreenState();
}

class _AddEditVaccinationScreenState extends State<AddEditVaccinationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vaccineNameController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _stickerPhotoPath;

  final ImagePicker _picker = ImagePicker();

  bool get _isEditing => widget.vaccination != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _vaccineNameController.text = widget.vaccination!.vaccineName;
      _selectedDate = widget.vaccination!.date;
      _stickerPhotoPath = widget.vaccination!.stickerPhotoPath;
    }
  }

  @override
  void dispose() {
    _vaccineNameController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickImage(ImageSource source, FormFieldState<String> state) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _stickerPhotoPath = pickedFile.path;
      });
    }
    state.validate();
  }

  // NUEVO: Diálogo para elegir entre cámara y galería
  Future<void> _showImageSourceDialog(FormFieldState<String> state) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Seleccionar Imagen'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Galería'),
                  onTap: () {
                    _pickImage(ImageSource.gallery, state);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Cámara'),
                  onTap: () {
                    _pickImage(ImageSource.camera, state);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _saveVaccination() async {
    if (_formKey.currentState!.validate()) {
      final dbHelper = DatabaseHelper();
      final String id = _isEditing ? widget.vaccination!.id : const Uuid().v4();

      final newVaccination = Vaccination(
        id: id,
        petId: widget.petId,
        vaccineName: _vaccineNameController.text,
        date: _selectedDate,
        stickerPhotoPath: _stickerPhotoPath,
      );

      if (_isEditing) {
        await dbHelper.updateVaccination(newVaccination);
      } else {
        await dbHelper.insertVaccination(newVaccination);
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
        title: Text(_isEditing ? 'Editar Vacunación' : 'Añadir Nueva Vacunación'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _vaccineNameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la Vacuna',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vaccines),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, introduce el nombre de la vacuna.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text('Fecha de Vacunación: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context),
              ),
              const SizedBox(height: 16),
              // Sección de foto del adhesivo con validación
              Text('Foto del adhesivo:', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              FormField<String>(
                validator: (value) {
                  if (_stickerPhotoPath == null || _stickerPhotoPath!.isEmpty) {
                    return 'Debes subir una foto del adhesivo de la vacuna.';
                  }
                  return null;
                },
                builder: (FormFieldState<String> state) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _showImageSourceDialog(state),
                        child: Container(
                          height: 250, // NUEVO: Altura del contenedor para que sea vertical
                          width: 180, // NUEVO: Ancho del contenedor para que sea vertical
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: state.hasError ? Colors.red : Colors.grey,
                              width: 2,
                            ),
                          ),
                          child: _stickerPhotoPath == null
                              ? const Center(child: Icon(Icons.add_a_photo, size: 50, color: Colors.grey))
                              : Image.file(
                            File(_stickerPhotoPath!),
                            fit: BoxFit.cover, // La imagen cubrirá el espacio sin dejar áreas vacías
                          ),
                        ),
                      ),
                      if (state.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                          child: Text(
                            state.errorText!,
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _saveVaccination,
                icon: const Icon(Icons.save),
                label: Text(_isEditing ? 'Actualizar Vacunación' : 'Guardar Vacunación'),
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