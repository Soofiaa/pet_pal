import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/note.dart';

/// Capa de acceso a datos para Notas. Es SOLO acceso a datos: a diferencia
/// de NotesNotifier, NO gestiona los archivos de photoPaths (guardarlos en
/// almacenamiento permanente al crear/editar, ni borrar los que sobran al
/// editar o eliminar un registro).
///
/// ⚠️ NO llames a insertNote/updateNote/deleteNote directamente desde una
/// pantalla. Hacerlo guarda o borra el registro pero deja photoPaths
/// desincronizado (rutas crudas del picker sin copiar a almacenamiento
/// permanente en un alta, o archivos huérfanos en petpal_files/notes/ tras
/// sacar una foto en una edición o eliminar el registro) — exactamente la
/// clase de bug silencioso que la suite de Fase 2 se armó para atrapar.
///
/// Toda mutación debe pasar por NotesNotifier
/// (lib/providers/note_providers.dart), que orquesta datos + archivos como
/// una sola operación.
class NoteRepository {
  NoteRepository(this._dbHelper);

  final DatabaseHelper _dbHelper;

  Future<List<Note>> getNotesForPet(String petId) {
    return _dbHelper.getNotesForPet(petId);
  }

  /// ⚠️ No llamar directo desde una pantalla — ver el comentario de la clase.
  /// Usa NotesNotifier.addNote, que también guarda las fotos en
  /// almacenamiento permanente antes de persistir el registro.
  Future<void> insertNote(Note note) {
    return _dbHelper.insertNote(note);
  }

  /// ⚠️ No llamar directo desde una pantalla — ver el comentario de la clase.
  /// Usa NotesNotifier.updateNote, que también guarda las fotos nuevas y
  /// limpia las que el usuario sacó sin dejarlas huérfanas.
  Future<void> updateNote(Note note) {
    return _dbHelper.updateNote(note);
  }

  /// ⚠️ No llamar directo desde una pantalla — ver el comentario de la clase.
  /// Usa NotesNotifier.deleteNote (o deleteNotes para el borrado múltiple),
  /// que también borra las fotos asociadas.
  Future<void> deleteNote(String id) {
    return _dbHelper.deleteNote(id);
  }
}
