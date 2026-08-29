import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pet_pal/models/note.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/providers/note_providers.dart';
import 'package:pet_pal/screens/add_edit_note_screen/add_edit_note_screen.dart';
import 'package:pet_pal/screens/image_preview_screen/image_preview_screen.dart';
import 'package:pet_pal/services/image_storage_service.dart';
import 'package:pet_pal/widgets/empty_state.dart';
import 'package:share_plus/share_plus.dart';

// ignore: library_prefixes
import '../../utils/pdf_generator.dart' as PdfGenerator;

class NotesScreen extends ConsumerStatefulWidget {
  final Pet pet;

  const NotesScreen({super.key, required this.pet});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedNoteIds = {};

  void _openImage(String imagePath, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImagePreviewScreen(
          imagePath: imagePath,
          title: title,
        ),
      ),
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) _selectedNoteIds.clear();
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

  Future<void> _deleteSelectedNotes(List<Note> notes) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: Text(
            'Se eliminarán ${_selectedNoteIds.length} nota(s) y sus imágenes asociadas. ¿Deseas continuar?',
          ),
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

    if (confirm != true) return;

    final notesToDelete = notes.where((note) => _selectedNoteIds.contains(note.id)).toList();

    try {
      final List<Note> failed =
          await ref.read(notesProvider(widget.pet.id).notifier).deleteNotes(notesToDelete);

      if (!mounted) return;

      final int deletedCount = notesToDelete.length - failed.length;
      final String message = failed.isEmpty
          ? '$deletedCount nota(s) eliminada(s) con éxito.'
          : '$deletedCount de ${notesToDelete.length} nota(s) eliminada(s); ${failed.length} fallaron.';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

      setState(() {
        _selectedNoteIds.clear();
        _isSelectionMode = false;
      });
    } catch (e) {
      debugPrint('Error al eliminar las notas: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar las notas: $e')),
      );
    }
  }

  Future<void> _exportNotesToPdf(List<Note> notes) async {
    if (_selectedNoteIds.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos una nota para exportar.')),
      );
      return;
    }

    final selectedNotes = notes.where((note) => _selectedNoteIds.contains(note.id)).toList();

    try {
      final Uint8List pdfData = await PdfGenerator.generateNotesPdf(widget.pet, selectedNotes);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/notas_pet_pal.pdf');
      await file.writeAsBytes(pdfData);

      await Share.shareXFiles([XFile(file.path)], text: 'Notas de ${widget.pet.name}');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF de notas generado y listo para compartir.')),
      );
    } catch (e) {
      debugPrint('Error al generar o compartir el PDF: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al exportar las notas.')),
      );
    }
  }

  Widget _buildNoteThumbnail(Note note) {
    final validPath = note.photoPaths
        .where((path) => ImageStorageService.isValidLocalFile(path))
        .firstOrNull;

    if (validPath == null) {
      return const Icon(Icons.description, color: Colors.blueGrey);
    }

    return GestureDetector(
      onTap: () => _openImage(validPath, note.title),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(validPath),
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesProvider(widget.pet.id));
    final List<Note> notes = notesAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('Notas de ${widget.pet.name}'),
        actions: [
          if (notes.isNotEmpty)
            if (_isSelectionMode) ...[
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: () => _exportNotesToPdf(notes),
                tooltip: 'Exportar a PDF',
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _deleteSelectedNotes(notes),
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
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Error: $error')),
        data: (notes) {
          if (notes.isEmpty) {
            return EmptyState(
              icon: Icons.note_alt_outlined,
              message: 'Aún no hay notas registradas para ${widget.pet.name}.',
              actionHint: 'Presiona "+" para añadir una nueva.',
            );
          }

          return ListView.builder(
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
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
                      : _buildNoteThumbnail(note),
                  title: Text(
                    note.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (note.photoPaths.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            '${note.photoPaths.length} imagen(es)',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  trailing: _isSelectionMode ? null : const Icon(Icons.chevron_right),
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
                      // No hace falta refrescar acá: si se guardó algo,
                      // NotesNotifier.addNote/updateNote ya refrescó el
                      // estado internamente antes de volver; si se
                      // canceló, no hay nada que refrescar.
                    }
                  },
                  onLongPress: () {
                    _toggleSelectionMode();
                    _toggleNoteSelection(note.id);
                  },
                ),
              );
            },
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
              },
              child: const Icon(Icons.add),
            ),
    );
  }
}

extension FirstOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull {
    if (isEmpty) return null;
    return first;
  }
}
