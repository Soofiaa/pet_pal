import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/note.dart';
import 'package:pet_pal/providers/database_providers.dart';
import 'package:pet_pal/repositories/note_repository.dart';
import 'package:pet_pal/services/image_storage_service.dart';

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepository(ref.watch(databaseHelperProvider));
});

/// Reemplaza los antiguos campos _notes/_isLoading manejados a mano en
/// notes_screen.dart. Es la única puerta de escritura real para Notas (ver
/// el comentario de NoteRepository): además de los datos, orquesta
/// ImageStorageService para la LISTA de fotos de cada nota, ya que los
/// archivos adjuntos son parte de la misma operación de guardar/eliminar.
final notesProvider = AsyncNotifierProvider.family<NotesNotifier, List<Note>, String>(
  NotesNotifier.new,
);

class NotesNotifier extends FamilyAsyncNotifier<List<Note>, String> {
  @override
  Future<List<Note>> build(String petId) async {
    final repository = ref.watch(noteRepositoryProvider);
    return repository.getNotesForPet(petId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build(arg));
  }

  /// Agrega una nota nueva. [rawPhotoPaths] son las rutas CRUDAS que dejó
  /// el picker en la pantalla (pueden no vivir en almacenamiento
  /// permanente todavía): se guardan acá antes de construir el registro,
  /// mismo motivo que DocumentsNotifier.addDocument.
  Future<void> addNote({
    required String petId,
    required String title,
    required String content,
    required DateTime date,
    List<String> rawPhotoPaths = const [],
  }) async {
    final List<String> savedPhotoPaths =
        await ImageStorageService.saveImagesIfNeeded(rawPhotoPaths, 'notes');

    final note = Note(
      petId: petId,
      title: title,
      content: content,
      date: date,
      photoPaths: savedPhotoPaths,
    );

    await ref.read(noteRepositoryProvider).insertNote(note);
    await refresh();
  }

  /// Actualiza una nota existente. Mismo patrón old+new que
  /// DocumentsNotifier.updateDocument, pero para una LISTA en vez de un
  /// solo archivo: [oldNote] es el registro vigente antes del cambio;
  /// [updatedNote].photoPaths es la lista final que dejó la pantalla
  /// (rutas ya guardadas que el usuario no tocó, más rutas crudas nuevas
  /// del picker, sin las que el usuario sacó).
  ///
  /// El diff es por Set: lo que está en ambas listas no se toca (ni se
  /// vuelve a guardar -saveImagesIfNeeded ya es un no-op para una ruta que
  /// ya vive en petpal_files/-, ni se borra); lo que estaba en [oldNote]
  /// pero ya no está en la lista final se borra del disco DESPUÉS de
  /// persistir el cambio -si updateNote fallara, la fila vigente sigue
  /// apuntando a esos archivos, así que borrarlos antes rompería una
  /// referencia real, mismo motivo que Document/Vaccination-.
  Future<void> updateNote(Note oldNote, Note updatedNote) async {
    final List<String> savedPhotoPaths =
        await ImageStorageService.saveImagesIfNeeded(updatedNote.photoPaths, 'notes');

    final finalNote = Note(
      id: updatedNote.id,
      petId: updatedNote.petId,
      title: updatedNote.title,
      content: updatedNote.content,
      date: updatedNote.date,
      photoPaths: savedPhotoPaths,
    );

    await ref.read(noteRepositoryProvider).updateNote(finalNote);

    final Set<String> removedPhotoPaths =
        oldNote.photoPaths.toSet().difference(savedPhotoPaths.toSet());
    await ImageStorageService.deleteFilesIfExist(removedPhotoPaths.toList());

    await refresh();
  }

  /// Elimina una nota: borra sus fotos y recién después el registro (mismo
  /// orden que usaba notes_screen.dart antes de esta migración).
  Future<void> deleteNote(Note note) async {
    await ImageStorageService.deleteFilesIfExist(note.photoPaths);
    await ref.read(noteRepositoryProvider).deleteNote(note.id);
    await refresh();
  }

  /// Elimina varias notas en una sola operación de usuario (modo de
  /// selección múltiple de notes_screen.dart). Best-effort: si una nota
  /// falla, sigue con el resto del lote en vez de abortarlo -no tiene
  /// sentido dejar sin borrar las demás porque una falló- y NO intenta
  /// revertir las que ya se borraron -un archivo borrado con éxito no se
  /// puede "des-borrar", así que el único rollback real posible sería
  /// dejar filas en la base sin sus fotos, exactamente el huérfano que el
  /// resto de esta migración evita-.
  ///
  /// Devuelve las notas que fallaron (lista vacía = éxito total) para que
  /// la pantalla arme el mensaje ("3 de 5 eliminadas"). Refresca el estado
  /// siempre al final, haya fallado algo o no.
  Future<List<Note>> deleteNotes(List<Note> notes) async {
    final repository = ref.read(noteRepositoryProvider);
    final List<Note> failed = [];

    for (final note in notes) {
      try {
        await ImageStorageService.deleteFilesIfExist(note.photoPaths);
        await repository.deleteNote(note.id);
      } catch (_) {
        failed.add(note);
      }
    }

    await refresh();
    return failed;
  }
}
