import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/document.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/services/image_storage_service.dart';

class AddEditDocumentScreen extends StatefulWidget {
  final Pet pet;
  final Document? document;

  const AddEditDocumentScreen({super.key, required this.pet, this.document});

  @override
  State<AddEditDocumentScreen> createState() => _AddEditDocumentScreenState();
}

class _AddEditDocumentScreenState extends State<AddEditDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _notasController = TextEditingController();

  late String _categoria;
  DateTime _fecha = DateTime.now();
  String? _filePath;

  bool get _isEditing => widget.document != null;

  @override
  void initState() {
    super.initState();
    _categoria = kDocumentCategories.first;

    if (widget.document != null) {
      _tituloController.text = widget.document!.titulo;
      _notasController.text = widget.document!.notas ?? '';
      _categoria = widget.document!.categoria;
      _fecha = widget.document!.fecha;
      _filePath = widget.document!.filePath;
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() => _fecha = picked);
    }
  }

  Future<void> _pickFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _filePath = result.files.single.path;
      });
    }
  }

  Future<void> _saveDocument() async {
    if (!_formKey.currentState!.validate()) return;

    if (_filePath == null || _filePath!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un archivo para el documento.')),
      );
      return;
    }

    try {
      final String? savedPath =
          await ImageStorageService.saveImageIfNeeded(_filePath, 'documents');

      final newDocument = Document(
        id: widget.document?.id,
        petId: widget.pet.id,
        categoria: _categoria,
        titulo: _tituloController.text,
        fecha: _fecha,
        filePath: savedPath!,
        notas: _notasController.text.trim().isEmpty ? null : _notasController.text.trim(),
      );

      if (_isEditing) {
        await DatabaseHelper().updateDocument(newDocument);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Documento actualizado con éxito.')),
          );
        }
      } else {
        await DatabaseHelper().insertDocument(newDocument);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Documento agregado con éxito.')),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error al guardar el documento: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar el documento: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? fileName = _filePath != null ? p.basename(_filePath!) : null;
    final bool fileIsPdf =
        fileName != null && p.extension(fileName).toLowerCase() == '.pdf';

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Documento' : 'Añadir Documento'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, introduce un título';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              DropdownButtonFormField<String>(
                initialValue: _categoria,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: kDocumentCategories
                    .map((categoria) => DropdownMenuItem(
                          value: categoria,
                          child: Text(categoria),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _categoria = value);
                  }
                },
              ),
              const SizedBox(height: 24.0),
              Text('Fecha:', style: Theme.of(context).textTheme.titleMedium),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(DateFormat('dd/MM/yyyy').format(_fecha)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _selectDate,
              ),
              const SizedBox(height: 16.0),
              Text('Archivo:', style: Theme.of(context).textTheme.titleMedium),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  fileName == null
                      ? Icons.attach_file
                      : (fileIsPdf ? Icons.picture_as_pdf : Icons.image),
                ),
                title: Text(fileName ?? 'Ningún archivo seleccionado'),
                trailing: const Icon(Icons.folder_open),
                onTap: _pickFile,
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _notasController,
                decoration: const InputDecoration(labelText: 'Notas (opcional)'),
                maxLines: 3,
              ),
              const SizedBox(height: 32.0),
              ElevatedButton.icon(
                onPressed: _saveDocument,
                icon: const Icon(Icons.save),
                label: Text(_isEditing ? 'Actualizar' : 'Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
