import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';
import 'package:pet_pal/screens/image_crop_screen/image_crop_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/vaccination.dart';
import 'package:pet_pal/models/vaccination_product.dart';
import 'package:pet_pal/providers/vaccination_providers.dart';
import 'package:pet_pal/screens/vaccination_products_screen/vaccination_products_screen.dart';
import 'package:pet_pal/services/image_storage_service.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class AddEditVaccinationScreen extends ConsumerStatefulWidget {
  final String petId;
  final Vaccination? vaccination;

  const AddEditVaccinationScreen({
    super.key,
    required this.petId,
    this.vaccination,
  });

  @override
  ConsumerState<AddEditVaccinationScreen> createState() => _AddEditVaccinationScreenState();
}

class _AddEditVaccinationScreenState extends ConsumerState<AddEditVaccinationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vaccineNameController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  DateTime? _nextDueDate;
  int _reminderDaysAhead = 0;
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
      _reminderDaysAhead = widget.vaccination!.reminderDaysAhead;
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
      final Uint8List? compressedBytes =
      await FlutterImageCompress.compressWithFile(
        path,
        quality: 90,
        format: CompressFormat.jpeg,
      );

      if (compressedBytes == null) return null;

      final Uint8List imageBytes = compressedBytes;

      if (!mounted) return null;

      final croppedBytes = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ImageCropScreen(
            imageBytes: imageBytes,
            title: 'Recortar',
          ),
        ),
      );

      if (croppedBytes == null || croppedBytes is! Uint8List) {
        return null;
      }

      final tempDir = Directory.systemTemp;

      final croppedFile = File(
        '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await croppedFile.writeAsBytes(croppedBytes);

      return croppedFile;
    } catch (e, stack) {
      debugPrint('Error en cropper Flutter: $e');
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

  void _onVaccineProductSelected(VaccinationProduct product) {
    setState(() {
      _vaccineNameController.text = product.name;
      _nextDueDate = DateTime(
        _selectedDate.year,
        _selectedDate.month + product.defaultFrequencyMonths,
        _selectedDate.day,
      );
    });
  }

  void _saveVaccination() async {
    if (_formKey.currentState!.validate()) {
      final String id = _isEditing ? widget.vaccination!.id : const Uuid().v4();

      try {
        final String? finalStickerPhotoPath =
            await ImageStorageService.saveImageIfNeeded(
          _stickerPhotoPath,
          'vaccinations',
        );

        final String? finalExtraPhotoPath =
            await ImageStorageService.saveImageIfNeeded(
          _extraPhotoPath,
          'vaccinations',
        );

        final newVaccination = Vaccination(
          id: id,
          petId: widget.petId,
          vaccineName: _normalizeVaccineName(_vaccineNameController.text),
          date: _selectedDate,
          nextDueDate: _nextDueDate,
          stickerPhotoPath: finalStickerPhotoPath,
          extraPhotoPath: finalExtraPhotoPath,
          reminderDaysAhead: _reminderDaysAhead,
        );

        final notifier = ref.read(vaccinationsProvider(widget.petId).notifier);

        if (_isEditing) {
          await notifier.updateVaccination(widget.vaccination!, newVaccination);
        } else {
          await notifier.addVaccination(newVaccination);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vacunación guardada con éxito.')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        debugPrint('Error al guardar la vacunación: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar la vacunación: $e')),
          );
        }
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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Gestionar Catálogo de Vacunas',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const VaccinationProductsScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Consumer(
                builder: (context, ref, child) {
                  final productsAsync = ref.watch(vaccinationProductsProvider);
                  return productsAsync.when(
                    data: (products) {
                      if (products.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: DropdownButtonFormField<VaccinationProduct>(
                          decoration: const InputDecoration(
                            labelText: 'Usar vacuna del catálogo',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.inventory_2),
                          ),
                          items: products
                              .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) _onVaccineProductSelected(val);
                          },
                        ),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (e, _) => const SizedBox.shrink(),
                  );
                },
              ),
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

              DropdownButtonFormField<int>(
                initialValue: _reminderDaysAhead,
                decoration: const InputDecoration(
                  labelText: 'Avisarme con anticipación',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notification_important),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('El mismo día')),
                  DropdownMenuItem(value: 1, child: Text('1 día antes')),
                  DropdownMenuItem(value: 2, child: Text('2 días antes')),
                  DropdownMenuItem(value: 3, child: Text('3 días antes')),
                  DropdownMenuItem(value: 7, child: Text('1 semana antes')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _reminderDaysAhead = value);
                },
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
                            child: File(_stickerPhotoPath!).existsSync()
                                ? Image.file(
                                    File(_stickerPhotoPath!),
                                    fit: BoxFit.cover,
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
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

              if (_extraPhotoPath != null &&
                  _extraPhotoPath!.isNotEmpty &&
                  File(_extraPhotoPath!).existsSync())
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_extraPhotoPath!),
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),

                    Positioned(
                      top: 8,
                      right: 8,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () {
                            setState(() {
                              _extraPhotoPath = null;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                )
              else
                Container(
                  margin: const EdgeInsets.only(bottom: 28),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _showExtraImageSourceDialog,
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.12),
                            Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.05),
                          ],
                        ),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.add_photo_alternate_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 28,
                            ),
                          ),

                          const SizedBox(width: 16),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Agregar foto adicional',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color:
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  'Cartilla, comprobante o información extra',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 18,
                            color: Theme.of(context)
                                .colorScheme
                                .primary,
                          ),
                        ],
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
