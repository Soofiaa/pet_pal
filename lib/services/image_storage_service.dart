import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ImageStorageService {
  static Future<String> saveImage(
      File imageFile,
      String folderName,
      ) async {
    final Directory appDir = await getApplicationDocumentsDirectory();

    final Directory targetDir = Directory(
      p.join(appDir.path, 'petpal_files', folderName),
    );

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final String extension = p.extension(imageFile.path);
    // El timestamp por sí solo no alcanza: dos archivos guardados en el
    // mismo milisegundo (posible en saveImagesIfNeeded al guardar varias
    // fotos en sucesión rápida) generarían el mismo nombre y File.copy
    // pisaría uno en silencio. El uuid es lo único acá que garantiza
    // unicidad real, sin importar tamaño ni timing.
    final String fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}$extension';

    final File savedImage = await imageFile.copy(
      p.join(targetDir.path, fileName),
    );

    return savedImage.path;
  }

  static Future<String?> saveImageIfNeeded(
      String? imagePath,
      String folderName,
      ) async {
    if (imagePath == null || imagePath.trim().isEmpty) {
      return null;
    }

    final File imageFile = File(imagePath);

    if (!await imageFile.exists()) {
      return imagePath;
    }

    final Directory appDir = await getApplicationDocumentsDirectory();
    final String appFilesPath = p.join(appDir.path, 'petpal_files');

    final String normalizedImagePath = p.normalize(imageFile.path);
    final String normalizedAppFilesPath = p.normalize(appFilesPath);

    if (normalizedImagePath.startsWith(normalizedAppFilesPath)) {
      return imagePath;
    }

    return saveImage(imageFile, folderName);
  }

  static Future<List<String>> saveImagesIfNeeded(
      List<String> imagePaths,
      String folderName,
      ) async {
    final List<String> savedPaths = [];

    for (final path in imagePaths) {
      final String? savedPath = await saveImageIfNeeded(path, folderName);

      if (savedPath != null && savedPath.trim().isNotEmpty) {
        savedPaths.add(savedPath);
      }
    }

    return savedPaths;
  }

  static bool isValidLocalFile(String? path) {
    if (path == null || path.trim().isEmpty) return false;

    final File file = File(path);
    return file.existsSync();
  }

  static Future<void> deleteFileIfExist(String? path) async {
    if (path == null || path.trim().isEmpty) return;

    final File file = File(path);

    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<void> deleteFilesIfExist(List<String?> paths) async {
    for (final path in paths) {
      await deleteFileIfExist(path);
    }
  }

  /// Borra [path] únicamente si vive físicamente bajo el directorio
  /// temporal del sistema (Directory.systemTemp) -la única condición bajo
  /// la que sabemos con certeza que es descartable-. Un path ya permanente
  /// (dentro de petpal_files/) o un archivo elegido por el usuario que la
  /// app nunca creó (ej. un PDF tomado directo de sus Descargas) queda
  /// fuera del directorio temporal, así que la llamada es un no-op seguro.
  ///
  /// Pensado para llamarse DESPUÉS de que el guardado completo -copia a
  /// almacenamiento permanente Y persistencia en base- haya terminado con
  /// éxito. Nunca antes, y nunca si algo en el medio falló: si la copia o
  /// el guardado en base lanzan una excepción, este método no debe
  /// alcanzarse, para no borrar la única copia que queda del archivo del
  /// usuario.
  static Future<void> deleteIfTemporary(String? path) async {
    if (path == null || path.trim().isEmpty) return;

    try {
      final File file = File(path);
      if (!await file.exists()) return;

      final String normalizedPath = p.normalize(file.path);
      final String normalizedTempPath = p.normalize(Directory.systemTemp.path);

      if (!p.isWithin(normalizedTempPath, normalizedPath)) return;

      await file.delete();
    } catch (_) {
      // Best-effort: un fallo al limpiar un temporal no debe reportarse
      // como error de guardado -el registro ya se persistió con éxito-.
    }
  }
}