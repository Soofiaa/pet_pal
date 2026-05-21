import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
    final String fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${imageFile.lengthSync()}$extension';

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
}