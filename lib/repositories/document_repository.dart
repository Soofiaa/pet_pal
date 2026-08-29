import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/document.dart';

/// Capa de acceso a datos para Documentos. Es SOLO acceso a datos: a
/// diferencia de DocumentsNotifier, NO gestiona el archivo adjunto
/// (guardarlo en almacenamiento permanente al crear/editar, ni borrarlo al
/// eliminar o reemplazar).
///
/// ⚠️ NO llames a insertDocument/updateDocument/deleteDocument
/// directamente desde una pantalla. Hacerlo guarda o borra el registro
/// pero deja el archivo desincronizado (ruta cruda del selector de
/// archivos sin copiar a almacenamiento permanente en un alta, o archivo
/// huérfano en petpal_files/documents/ tras un reemplazo o eliminación) —
/// exactamente la clase de bug silencioso que la suite de Fase 1 se armó
/// para atrapar.
///
/// Toda mutación debe pasar por DocumentsNotifier
/// (lib/providers/document_providers.dart), que orquesta datos + archivo
/// como una sola operación.
class DocumentRepository {
  DocumentRepository(this._dbHelper);

  final DatabaseHelper _dbHelper;

  Future<List<Document>> getDocumentsForPet(String petId) {
    return _dbHelper.getDocumentsForPet(petId);
  }

  /// ⚠️ No llamar directo desde una pantalla — ver el comentario de la clase.
  /// Usa DocumentsNotifier.addDocument, que también guarda el archivo en
  /// almacenamiento permanente antes de persistir el registro.
  Future<void> insertDocument(Document document) {
    return _dbHelper.insertDocument(document);
  }

  /// ⚠️ No llamar directo desde una pantalla — ver el comentario de la clase.
  /// Usa DocumentsNotifier.updateDocument, que también guarda el archivo
  /// nuevo y limpia el reemplazado.
  Future<void> updateDocument(Document document) {
    return _dbHelper.updateDocument(document);
  }

  /// ⚠️ No llamar directo desde una pantalla — ver el comentario de la clase.
  /// Usa DocumentsNotifier.deleteDocument, que también borra el archivo.
  Future<void> deleteDocument(String id) {
    return _dbHelper.deleteDocument(id);
  }
}
