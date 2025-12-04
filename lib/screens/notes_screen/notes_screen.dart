import 'package:flutter/material.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/note.dart';
import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/screens/add_edit_note_screen/add_edit_note_screen.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
// ignore: library_prefixes
import '../../utils/pdf_generator.dart' as PdfGenerator;

class NotesScreen extends StatefulWidget {
  final Pet pet;

  const NotesScreen({super.key, required this.pet});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Note> _notes = [];
  bool _isLoading = true;
  bool _isSelectionMode = false;
  final Set<String> _selectedNoteIds = {};

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
    });
    final notes = await DatabaseHelper().getNotesForPet(widget.pet.id);
    notes.sort((a, b) => b.date.compareTo(a.date));
    setState(() {
      _notes = notes;
      _isLoading = false;
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedNoteIds.clear();
      }
    });
  }

  void _toggleNoteSelection(String noteId) {
    setState(() {
      if (_selectedNoteIds.contains(noteId)) {
        _selectedNoteIds.remove(noteId);
      } else {
        _selectedNoteIds.add(noteId);
      }
    });
  }

  Future<void> _deleteSelectedNotes() async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text('¿Estás seguro de que quieres eliminar ${_selectedNoteIds.length} notas?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final dbHelper = DatabaseHelper();
      for (final id in _selectedNoteIds) {
        await dbHelper.deleteNote(id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_selectedNoteIds.length} notas eliminadas con éxito.')),
        );
      }
      _selectedNoteIds.clear();
      _isSelectionMode = false;
      _loadNotes();
    }
  }

  void _exportNotesToPdf() async {
    if (_selectedNoteIds.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona al menos una nota para exportar.')),
        );
      }
      return;
    }

    final selectedNotes = _notes.where((note) => _selectedNoteIds.contains(note.id)).toList();

    try {
      // CORRECCIÓN: Se usa `widget.pet` en lugar de `_pet`
      final Uint8List pdfData = await PdfGenerator.generateNotesPdf(widget.pet, selectedNotes);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/notas_pet_pal.pdf');
      await file.writeAsBytes(pdfData);

      // CORRECCIÓN: Se usa `widget.pet.name` en lugar de `_pet.name`
      await Share.shareXFiles([XFile(file.path)], text: 'Notas de ${widget.pet.name}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF de notas generado y listo para compartir.')),
        );
      }
    } catch (e) {
      debugPrint('Error al generar o compartir el PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al exportar las notas.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notas de ${widget.pet.name}'),
        actions: [
          if (_notes.isNotEmpty)
            if (_isSelectionMode) ...[
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: _exportNotesToPdf,
                tooltip: 'Exportar a PDF',
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _deleteSelectedNotes,
                tooltip: 'Eliminar seleccionadas',
              ),
              IconButton(
                icon: const Icon(Icons.cancel),
                onPressed: _toggleSelectionMode,
                tooltip: 'Cancelar',
              ),
            ] else ...[
              IconButton(
                icon: const Icon(Icons.select_all),
                onPressed: _toggleSelectionMode,
                tooltip: 'Seleccionar notas',
              ),
            ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No hay notas registradas para esta mascota.\nPresiona "+" para añadir una nueva.',
            style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
      )
          : ListView.builder(
        itemCount: _notes.length,
        itemBuilder: (context, index) {
          final note = _notes[index];
          final isSelected = _selectedNoteIds.contains(note.id);
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: isSelected ? Colors.blue.shade50 : null,
            child: ListTile(
              leading: _isSelectionMode
                  ? Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? Colors.blue : Colors.grey,
              )
                  : const Icon(Icons.description, color: Colors.blueGrey),
              title: Text(
                note.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                note.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: _isSelectionMode
                  ? null
                  : const Icon(Icons.chevron_right),
              onTap: () async {
                if (_isSelectionMode) {
                  _toggleNoteSelection(note.id);
                } else {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddEditNoteScreen(pet: widget.pet, note: note),
                    ),
                  );
                  _loadNotes();
                }
              },
              onLongPress: () {
                _toggleSelectionMode();
                _toggleNoteSelection(note.id);
              },
            ),
          );
        },
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEditNoteScreen(pet: widget.pet),
            ),
          );
          _loadNotes();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}