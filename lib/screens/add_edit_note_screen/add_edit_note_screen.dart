import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pet_pal/models/note.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/providers/note_providers.dart';
import 'package:pet_pal/services/image_storage_service.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:io';

class AddEditNoteScreen extends ConsumerStatefulWidget {
  final Pet pet;
  final Note? note;

  const AddEditNoteScreen({super.key, required this.pet, this.note});

  @override
  ConsumerState<AddEditNoteScreen> createState() => _AddEditNoteScreenState();
}

class _AddEditNoteScreenState extends ConsumerState<AddEditNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  List<String> _photoPaths = [];
  bool _isSaving = false;

  // Snapshot para detectar cambios sin guardar al salir (ver _isDirty).
  late String _initialTitle;
  late String _initialContent;
  late DateTime _initialDate;
  late List<String> _initialPhotoPaths;

  final ImagePicker _picker = ImagePicker();

  bool get _isEditing => widget.note != null;

  bool get _isDirty {
    return _titleController.text != _initialTitle ||
        _contentController.text != _initialContent ||
        _selectedDate != _initialDate ||
        !listEquals(_photoPaths, _initialPhotoPaths);
  }

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
      _selectedDate = widget.note!.date;
      // Copia, no referencia: widget.note!.photoPaths es la misma lista que
      // vive en el objeto Note de notes_screen.dart. Mutarla acá (agregar o
      // sacar fotos) sin copiarla primero dejaba ese estado en memoria
      // desincronizado de la base si el usuario salía sin guardar.
      _photoPaths = List.of(widget.note!.photoPaths);
    }

    _markSaved();
  }

  /// Actualiza el snapshot "guardado" a los valores actuales: usarlo tanto
  /// al abrir la pantalla (nada sin guardar todavía) como después de un
  /// guardado exitoso (para que la confirmación de salida no se dispare
  /// justo cuando se hace el pop programático tras guardar).
  void _markSaved() {
    _initialTitle = _titleController.text;
    _initialContent = _contentController.text;
    _initialDate = _selectedDate;
    _initialPhotoPaths = List.of(_photoPaths);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
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

  // NUEVO: Diálogo para elegir entre cámara y galería
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
                    _pickImages(ImageSource.gallery);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Cámara'),
                  onTap: () {
                    _pickImages(ImageSource.camera);
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

  // Comprime cada foto elegida (misma calidad/formato que el resto de la
  // app, ver add_edit_vaccination_screen.dart) antes de guardarla en el
  // estado. Si la compresión falla, se sigue con la ruta original en vez
  // de bloquear al usuario.
  Future<String> _compressImage(String path) async {
    try {
      final Uint8List? compressedBytes =
          await FlutterImageCompress.compressWithFile(
        path,
        quality: 90,
        format: CompressFormat.jpeg,
      );

      if (compressedBytes == null) return path;

      final tempDir = Directory.systemTemp;
      final compressedFile = File('${tempDir.path}/${const Uuid().v4()}.jpg');
      await compressedFile.writeAsBytes(compressedBytes);

      return compressedFile.path;
    } catch (e, stack) {
      debugPrint('Error al comprimir imagen: $e');
      debugPrintStack(stackTrace: stack);
      return path;
    }
  }

  // ACTUALIZADO: Maneja la selección de imágenes desde cualquier fuente
  Future<void> _pickImages(ImageSource source) async {
    if (source == ImageSource.gallery) {
      final pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        final List<String> compressedPaths = [];
        for (final file in pickedFiles) {
          compressedPaths.add(await _compressImage(file.path));
        }
        setState(() {
          _photoPaths.addAll(compressedPaths);
        });
      }
    } else {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final String compressedPath = await _compressImage(pickedFile.path);
        setState(() {
          _photoPaths.add(compressedPath);
        });
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photoPaths.removeAt(index);
    });
  }

  Future<bool> _confirmDiscardChanges() async {
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Descartar cambios?'),
        content: const Text('Tenés cambios sin guardar. Si salís ahora, se perderán.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Seguir editando'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _saveNote() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa los campos marcados en rojo antes de guardar.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final notifier = ref.read(notesProvider(widget.pet.id).notifier);

      if (_isEditing) {
        final Note draft = Note(
          id: widget.note!.id,
          petId: widget.pet.id,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          date: _selectedDate,
          photoPaths: _photoPaths,
        );
        await notifier.updateNote(widget.note!, draft);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nota actualizada con éxito.')),
          );
        }
      } else {
        await notifier.addNote(
          petId: widget.pet.id,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          date: _selectedDate,
          rawPhotoPaths: _photoPaths,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nota guardada con éxito.')),
          );
        }
      }

      // Recién acá el guardado completo (copia + base) es un éxito
      // confirmado: es seguro borrar los temporales de origen, si los había.
      for (final photoPath in _photoPaths) {
        await ImageStorageService.deleteIfTemporary(photoPath);
      }

      _markSaved();

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error al guardar la nota: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar la nota: $e')),
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
    return PopScope<Object?>(
      canPop: !_isDirty,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final bool shouldDiscard = await _confirmDiscardChanges();
        if (shouldDiscard && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Editar Nota' : 'Añadir Nueva Nota'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Título de la Nota',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, introduce un título';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    labelText: 'Contenido',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit_note),
                  ),
                  maxLines: 5,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, introduce el contenido de la nota';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text('Fecha: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _selectDate(context),
                ),
                const SizedBox(height: 16),
                Text('Fotos (opcional):', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    ..._photoPaths.asMap().entries.map((entry) {
                      final index = entry.key;
                      final photoPath = entry.value;
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: File(photoPath).existsSync()
                                ? Image.file(
                                    File(photoPath),
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 100,
                                    height: 100,
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                    ),
                                  ),
                          ),
                          Positioned(
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _removePhoto(index),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                    GestureDetector(
                      onTap: _showImageSourceDialog, // Llama al nuevo diálogo
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveNote,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isEditing ? 'Actualizar Nota' : 'Guardar Nota'),
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
      ),
    );
  }
}
