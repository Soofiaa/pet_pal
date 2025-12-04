import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/data/database_helper.dart';

class AddEditPetScreen extends StatefulWidget {
  final Pet? pet;

  const AddEditPetScreen({super.key, this.pet});

  @override
  State<AddEditPetScreen> createState() => _AddEditPetScreenState();
}

class _AddEditPetScreenState extends State<AddEditPetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _speciesController = TextEditingController();
  final _breedController = TextEditingController();
  final _colorController = TextEditingController();
  DateTime _selectedDateOfBirth = DateTime.now();
  String? _imagePath;

  final ImagePicker _picker = ImagePicker();

  bool get _isEditing => widget.pet != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.pet!.name;
      _speciesController.text = widget.pet!.species;
      _breedController.text = widget.pet!.breed;
      _colorController.text = widget.pet!.color;
      _selectedDateOfBirth = widget.pet!.dob;
      _imagePath = widget.pet!.imageUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _speciesController.dispose();
    _breedController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = picked;
      });
    }
  }

  Future<void> _showImageSourceDialog() async {
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
                    _pickAndCropImage(ImageSource.gallery);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Cámara'),
                  onTap: () {
                    _pickAndCropImage(ImageSource.camera);
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

  // Función para seleccionar y recortar la imagen
  Future<void> _pickAndCropImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);

    if (pickedFile != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recortar',
            toolbarColor: Theme.of(context).primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false, // Asegúrate de que esto esté en 'false' o no exista para mostrar los botones
            showCropGrid: true,
          ),
          IOSUiSettings(
            title: 'Recortar',
            aspectRatioLockEnabled: true,
            aspectRatioPickerButtonHidden: true,
            doneButtonTitle: 'Aceptar',
            cancelButtonTitle: 'Cancelar',
          ),
        ],
      );

      // Si se recortó correctamente, actualiza el estado y la interfaz
      if (croppedFile != null) {
        // Esta llamada a setState es lo que actualiza la imagen en la pantalla.
        setState(() {
          _imagePath = croppedFile.path;
        });
      }
    }
  }

  void _savePet() async {
    if (_formKey.currentState!.validate()) {
      final dbHelper = DatabaseHelper();
      final String id = widget.pet?.id ?? const Uuid().v4();

      final newPet = Pet(
        id: id,
        name: _nameController.text,
        species: _speciesController.text,
        breed: _breedController.text,
        dob: _selectedDateOfBirth,
        color: _colorController.text,
        imageUrl: _imagePath,
      );

      if (_isEditing) {
        await dbHelper.updatePet(newPet);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mascota actualizada con éxito.')),
          );
        }
      } else {
        await dbHelper.insertPet(newPet);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mascota guardada con éxito.')),
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
        title: Text(_isEditing ? 'Editar Mascota' : 'Añadir Nueva Mascota'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: _showImageSourceDialog,
                child: CircleAvatar(
                  radius: 80,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: _imagePath != null ? FileImage(File(_imagePath!)) : null,
                  child: _imagePath == null
                      ? Icon(Icons.camera_alt, size: 50, color: Colors.grey[800])
                      : null,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pets),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, introduce el nombre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _speciesController,
                decoration: const InputDecoration(
                  labelText: 'Especie (ej. Perro, Gato)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, introduce la especie';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _breedController,
                decoration: const InputDecoration(
                  labelText: 'Raza',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pets_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, introduce la raza';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  'Fecha de Nacimiento: ${DateFormat('dd/MM/yyyy').format(_selectedDateOfBirth)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDateOfBirth(context),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _colorController,
                decoration: const InputDecoration(
                  labelText: 'Color',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.color_lens),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, introduce el color';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _savePet,
                  icon: const Icon(Icons.save),
                  label: Text(_isEditing ? 'Actualizar Mascota' : 'Guardar Mascota'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(fontSize: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}