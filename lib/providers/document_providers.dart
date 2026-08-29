import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/document.dart';
import 'package:pet_pal/providers/database_providers.dart';
import 'package:pet_pal/repositories/document_repository.dart';
import 'package:pet_pal/services/image_storage_service.dart';

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository(ref.watch(databaseHelperProvider));
});

/// Reemplaza los antiguos campos _documents/_isLoading manejados a mano en
/// documents_screen.dart. Es la única puerta de escritura real para
/// Documentos (ver el comentario de DocumentRepository): además de los
/// datos, orquesta ImageStorageService, ya que el archivo adjunto es parte
/// de la misma operación de guardar/eliminar.
final documentsProvider = AsyncNotifierProvider.family<DocumentsNotifier, List<Document>, String>(
  DocumentsNotifier.new,
);

class DocumentsNotifier extends FamilyAsyncNotifier<List<Document>, String> {
  @override
  Future<List<Document>> build(String petId) async {
    final repository = ref.watch(documentRepositoryProvider);
    return repository.getDocumentsForPet(petId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build(arg));
  }

  /// [rawFilePath] no necesariamente vive en almacenamiento permanente
  /// (puede ser la ruta que devolvió el selector de archivos, fuera de
  /// petpal_files/); ImageStorageService.saveImageIfNeeded la copia ahí si
  /// hace falta y devuelve la ruta final, o la misma ruta sin tocar si ya
  /// estaba adentro (caso de una edición donde el usuario no cambió el
  /// archivo). Solo devuelve `null` si le pasan una ruta vacía, lo que no
  /// debería pasar acá: la pantalla ya valida que haya un archivo elegido
  /// antes de llamar a addDocument/updateDocument.
  Future<String> _saveDocumentFile(String rawFilePath) async {
    final String? savedPath = await ImageStorageService.saveImageIfNeeded(rawFilePath, 'documents');
    return savedPath!;
  }

  /// Agrega un documento nuevo. A diferencia de VaccinationsNotifier.addVaccination
  /// (que recibe un Vaccination ya armado porque la pantalla resuelve el
  /// guardado de fotos antes de llamar), acá se recibe la ruta CRUDA del
  /// archivo elegido: la pantalla no necesita saber nada de almacenamiento,
  /// este método guarda el archivo primero y recién con la ruta final
  /// construye el registro.
  Future<void> addDocument({
    required String petId,
    required String categoria,
    required String titulo,
    required DateTime fecha,
    required String rawFilePath,
    String? notas,
  }) async {
    final String filePath = await _saveDocumentFile(rawFilePath);

    final document = Document(
      petId: petId,
      categoria: categoria,
      titulo: titulo,
      fecha: fecha,
      filePath: filePath,
      notas: notas,
    );

    await ref.read(documentRepositoryProvider).insertDocument(document);
    await refresh();
  }

  /// Actualiza un documento existente. Mismo patrón old+new que
  /// VaccinationsNotifier.updateVaccination: [oldDocument] es el registro
  /// vigente antes del cambio; en [updatedDocument] el campo `filePath` es
  /// la ruta CRUDA elegida por el usuario -la misma ruta ya guardada si no
  /// tocó el archivo, o una ruta nueva del selector de archivos si sí lo
  /// reemplazó- y recién se guarda a almacenamiento permanente acá adentro.
  ///
  /// El archivo viejo se borra DESPUÉS de persistir el cambio, por el mismo
  /// motivo que en Vaccination: si updateDocument fallara, la fila vigente
  /// en la base sigue apuntando al archivo viejo, así que borrarlo antes
  /// rompería una referencia real. Si el archivo no cambió, `filePath` final
  /// coincide con el viejo y no se borra nada.
  Future<void> updateDocument(Document oldDocument, Document updatedDocument) async {
    final String filePath = await _saveDocumentFile(updatedDocument.filePath);

    final finalDocument = Document(
      id: updatedDocument.id,
      petId: updatedDocument.petId,
      categoria: updatedDocument.categoria,
      titulo: updatedDocument.titulo,
      fecha: updatedDocument.fecha,
      filePath: filePath,
      notas: updatedDocument.notas,
    );

    await ref.read(documentRepositoryProvider).updateDocument(finalDocument);

    if (oldDocument.filePath != finalDocument.filePath) {
      await ImageStorageService.deleteFileIfExist(oldDocument.filePath);
    }

    await refresh();
  }

  /// Elimina un documento: borra el archivo y recién después el registro
  /// (mismo orden que usaba documents_screen.dart antes de esta migración).
  Future<void> deleteDocument(Document document) async {
    await ImageStorageService.deleteFileIfExist(document.filePath);
    await ref.read(documentRepositoryProvider).deleteDocument(document.id);
    await refresh();
  }
}
