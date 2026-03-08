import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/vaccination.dart';
import 'package:uuid/uuid.dart';

class AddEditVaccinationScreen extends StatefulWidget {
  final String petId;
  final Vaccination? vaccination;

  const AddEditVaccinationScreen({
    super.key,
    required this.petId,
    this.vaccination,
  });

  @override
  State<AddEditVaccinationScreen> createState() => _AddEditVaccinationScreenState();
}

class _AddEditVaccinationScreenState extends State<AddEditVaccinationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vaccineNameController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  DateTime? _nextDueDate;
  String? _stickerPhotoPath;
  String? _extraPhotoPath;

  final ImagePicker _picker = ImagePicker();
  List<String> _vaccineSuggestions = [];

  bool get _isEditing => widget.vaccination != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _vaccineNameController.text = widget.vaccination!.vaccineName;
      _selectedDate = widget.vaccination!.date;
      _nextDueDate = widget.vaccination!.nextDueDate;
      _stickerPhotoPath = widget.vaccination!.stickerPhotoPath;
      _extraPhotoPath = widget.vaccination!.extraPhotoPath;
    }
    _loadVaccineSuggestions();
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
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _loadVaccineSuggestions() async {
    final dbHelper = DatabaseHelper();
    final names = await dbHelper.getVaccineNames();

    if (!mounted) return;

    setState(() {
      _vaccineSuggestions = names;
    });
  }

  Future<void> _selectNextDueDate(BuildContext context) async {
    final DateTime initialDate = _nextDueDate ?? _selectedDate.add(const Duration(days: 30));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _selectedDate,
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => _nextDueDate = picked);
    }
  }

  Future<File?> _cropImage(String path) async {
    try {
      debugPrint("✂️ Abriendo cropper...");

      final cropped = await ImageCropper().cropImage(
        sourcePath: path,
        compressQuality: 85,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recortar adhesivo',
            toolbarColor: Theme.of(context).primaryColor,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Recortar adhesivo',
            aspectRatioLockEnabled: false,
          ),
        ],
      );

      if (cropped == null) {
        debugPrint("⚠️ Cropper cancelado");
        return null;
      }

      debugPrint("✂️ Cropper OK: ${cropped.path}");

      return File(cropped.path);

    } catch (e, stack) {
      debugPrint("💥 ERROR en cropper");
      debugPrint("Error: $e");
      debugPrintStack(stackTrace: stack);
      return null;
    }
  }

  Future<void> _pickImage(ImageSource source, FormFieldState<String> state) async {
    try {
      debugPrint("📷 Iniciando selección de imagen...");

      final pickedFile = await _picker.pickImage(source: source);

      if (pickedFile == null) {
        debugPrint("⚠️ Usuario canceló selección de imagen");
        if (mounted) state.validate();
        return;
      }

      debugPrint("📷 Imagen seleccionada: ${pickedFile.path}");

      final croppedFile = await _cropImage(pickedFile.path);

      if (croppedFile == null) {
        debugPrint("⚠️ Usuario canceló recorte");
        if (mounted) state.validate();
        return;
      }

      debugPrint("✂️ Imagen recortada: ${croppedFile.path}");

      if (!mounted) return;

      setState(() {
        _stickerPhotoPath = croppedFile.path;
      });

      debugPrint("✅ Imagen guardada en estado");

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          state.validate();
        }
      });

    } catch (e, stack) {
      debugPrint("💥 ERROR al seleccionar/recortar imagen");
      debugPrint("Error: $e");
      debugPrintStack(stackTrace: stack);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error al procesar la imagen."),
        ),
      );
    }
  }

  Future<void> _pickExtraImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile == null) return;

      final croppedFile = await _cropImage(pickedFile.path);
      if (croppedFile == null) return;

      if (!mounted) return;

      setState(() {
        _extraPhotoPath = croppedFile.path;
      });
    } catch (e, stack) {
      debugPrint("💥 ERROR al seleccionar imagen extra");
      debugPrint("Error: $e");
      debugPrintStack(stackTrace: stack);
    }
  }

  // Diálogo para elegir entre cámara y galería
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
                    Navigator.of(context).pop();
                    _pickImage(ImageSource.gallery, state);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Cámara'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickImage(ImageSource.camera, state);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showExtraImageSourceDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Seleccionar Imagen Adicional'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Galería'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickExtraImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Cámara'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickExtraImage(ImageSource.camera);
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
        vaccineName: _normalizeVaccineName(_vaccineNameController.text),
        date: _selectedDate,
        nextDueDate: _nextDueDate,
        stickerPhotoPath: _stickerPhotoPath,
        extraPhotoPath: _extraPhotoPath,
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

  String _normalizeVaccineName(String value) {
    final trimmed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return trimmed;

    return trimmed
        .split(' ')
        .map((word) => word.isEmpty
        ? word
        : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
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
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _vaccineNameController.text),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  final query = textEditingValue.text.trim().toLowerCase();

                  if (query.isEmpty) {
                    return _vaccineSuggestions;
                  }

                  return _vaccineSuggestions.where((option) {
                    return option.toLowerCase().contains(query);
                  });
                },
                onSelected: (String selection) {
                  _vaccineNameController.text = selection;
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
                      labelText: 'Nombre de la Vacuna',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.vaccines),
                    ),
                    onChanged: (value) {
                      _vaccineNameController.text = value;
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor, introduce el nombre de la vacuna.';
                      }
                      return null;
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  'Fecha de Vacunación: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context),
              ),
              const SizedBox(height: 16),

              // Sección de próxima vacunación
              ListTile(
                title: Text(
                  _nextDueDate == null
                      ? 'Próxima vacunación (opcional)'
                      : 'Próxima vacunación: ${DateFormat('dd/MM/yyyy').format(_nextDueDate!)}',
                ),
                trailing: const Icon(Icons.event_repeat),
                onTap: () => _selectNextDueDate(context),
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
                          height: 250,
                          width: 180,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: state.hasError ? Colors.red : Colors.grey,
                              width: 2,
                            ),
                          ),
                          child: _stickerPhotoPath == null
                              ? const Center(
                            child: Icon(
                              Icons.add_a_photo,
                              size: 50,
                              color: Colors.grey,
                            ),
                          )
                              : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_stickerPhotoPath!),
                              fit: BoxFit.cover,
                            ),
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

              Text(
                'Foto adicional (opcional):',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),

              GestureDetector(
                onTap: _showExtraImageSourceDialog,
                child: Container(
                  height: 250,
                  width: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.grey,
                      width: 2,
                    ),
                  ),
                  child: _extraPhotoPath == null
                      ? const Center(
                    child: Icon(
                      Icons.add_photo_alternate,
                      size: 50,
                      color: Colors.grey,
                    ),
                  )
                      : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_extraPhotoPath!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

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
