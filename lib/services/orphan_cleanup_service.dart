import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pet_pal/data/database_helper.dart';

/// Una fila cuyo campo JSON (ej. photoPaths) no se pudo decodificar al
/// construir el conjunto de rutas en uso. Se excluye de ese conjunto, así
/// que sus archivos (si existen) corren riesgo de ser puestos en cuarentena
/// por error; se reporta aparte para poder cruzarla manualmente contra la
/// lista de archivos movidos antes de confiar en el resultado.
class JsonDecodeFailure {
  final String table;
  final String rowId;
  final String rawValue;

  const JsonDecodeFailure({
    required this.table,
    required this.rowId,
    required this.rawValue,
  });
}

/// Limpieza única de archivos en petpal_files/ que ya no están referenciados
/// por ninguna fila de la base de datos (heredado de cuando ON DELETE
/// CASCADE aún no se aplicaba). Se apoya en la migración v17 de
/// DatabaseHelper: solo se ejecuta en el mismo lanzamiento en que esa
/// migración corrió, para que sea, igual que la limpieza de filas, una
/// operación de una sola vez.
class OrphanCleanupService {
  OrphanCleanupService._();

  static const String _quarantinePrefix = '_huerfanos_';

  /// Punto de entrada. Pensado para llamarse (unawaited) al arrancar la
  /// app. Nunca lanza: cualquier falla se registra y se ignora, ya que esto
  /// es mantenimiento, no algo de lo que dependa que la app abra.
  static Future<void> runOnce() async {
    try {
      // Fuerza la apertura de la conexión (dispara _onConfigure/_onUpgrade
      // si corresponde) antes de decidir si la migración v17 corrió ahora.
      await DatabaseHelper().database;

      final Map<String, int>? rowCounts = DatabaseHelper.lastOrphanRowCleanupCounts;
      if (rowCounts == null) {
        // La migración v17 ya corrió en un lanzamiento anterior (o esta es
        // una instalación nueva sin datos heredados): nada que hacer.
        return;
      }

      final (Set<String> usedPaths, List<JsonDecodeFailure> decodeFailures) =
          await _collectUsedFilePaths();

      List<String> quarantinedFiles = const [];
      try {
        quarantinedFiles = await _quarantineOrphanFiles(usedPaths);
      } catch (e, stack) {
        debugPrint('Limpieza de archivos huérfanos falló (no crítico): $e');
        debugPrintStack(stackTrace: stack);
      }

      _printSummary(rowCounts, quarantinedFiles, decodeFailures);
    } catch (e, stack) {
      debugPrint('OrphanCleanupService.runOnce falló por completo (no crítico): $e');
      debugPrintStack(stackTrace: stack);
    }
  }

  static Future<List<String>> _quarantineOrphanFiles(Set<String> usedPaths) async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory petpalFilesDir = Directory(p.join(appDir.path, 'petpal_files'));

    if (!await petpalFilesDir.exists()) {
      return const [];
    }

    final Directory quarantineDir = Directory(
      p.join(petpalFilesDir.path, '$_quarantinePrefix${DateTime.now().millisecondsSinceEpoch}'),
    );

    final List<String> movedFiles = [];

    await for (final entity in petpalFilesDir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;

      final String normalizedPath = p.normalize(entity.path);

      // Nunca tratar como huérfano nada que ya esté dentro de una carpeta
      // de cuarentena (la de esta corrida, o de una anterior).
      final bool insideQuarantine = p
          .split(normalizedPath)
          .any((segment) => segment.startsWith(_quarantinePrefix));
      if (insideQuarantine) continue;

      if (usedPaths.contains(normalizedPath)) continue;

      if (!await quarantineDir.exists()) {
        await quarantineDir.create(recursive: true);
      }

      String destinationPath = p.join(quarantineDir.path, p.basename(entity.path));
      int suffix = 1;
      while (await File(destinationPath).exists()) {
        final String baseName = p.basenameWithoutExtension(entity.path);
        final String extension = p.extension(entity.path);
        destinationPath = p.join(quarantineDir.path, '${baseName}_$suffix$extension');
        suffix++;
      }

      await entity.rename(destinationPath);
      movedFiles.add(destinationPath);
    }

    return movedFiles;
  }

  static Future<(Set<String>, List<JsonDecodeFailure>)> _collectUsedFilePaths() async {
    final db = await DatabaseHelper().database;
    final Set<String> used = {};
    final List<JsonDecodeFailure> decodeFailures = [];

    final petRows = await db.query(DatabaseHelper.petsTable);
    for (final row in petRows) {
      _addIfPresent(used, row['imageUrl'] as String?);
    }

    final noteRows = await db.query(DatabaseHelper.notesTable);
    for (final row in noteRows) {
      final String? photoPathsJson = row['photoPaths'] as String?;
      if (photoPathsJson == null || photoPathsJson.trim().isEmpty) continue;

      try {
        final List<dynamic> decoded = jsonDecode(photoPathsJson);
        for (final path in decoded) {
          if (path is String) _addIfPresent(used, path);
        }
      } catch (e) {
        final String rowId = (row['id'] ?? '').toString();
        decodeFailures.add(JsonDecodeFailure(
          table: DatabaseHelper.notesTable,
          rowId: rowId,
          rawValue: photoPathsJson,
        ));
        debugPrint('No se pudo decodificar photoPaths de la nota $rowId durante la limpieza de huérfanos: $e');
      }
    }

    final vaccinationRows = await db.query(DatabaseHelper.vaccinationsTable);
    for (final row in vaccinationRows) {
      _addIfPresent(used, row['stickerPhotoPath'] as String?);
      _addIfPresent(used, row['extraPhotoPath'] as String?);
    }

    final documentRows = await db.query(DatabaseHelper.documentsTable);
    for (final row in documentRows) {
      _addIfPresent(used, row['filePath'] as String?);
    }

    return (used, decodeFailures);
  }

  static void _addIfPresent(Set<String> paths, String? path) {
    if (path != null && path.trim().isNotEmpty) {
      paths.add(p.normalize(path));
    }
  }

  static void _printSummary(
    Map<String, int> rowCounts,
    List<String> quarantinedFiles,
    List<JsonDecodeFailure> decodeFailures,
  ) {
    debugPrint('===== Limpieza de datos heredados (migración v17) =====');
    debugPrint('Parte A - Filas huérfanas eliminadas por tabla:');
    rowCounts.forEach((table, count) {
      debugPrint('  $table: $count');
    });
    debugPrint('Parte B - Archivos movidos a cuarentena: ${quarantinedFiles.length}');
    for (final path in quarantinedFiles) {
      debugPrint('  $path');
    }
    debugPrint(
      'Parte B - Filas con JSON no decodificable (excluidas del cálculo de '
      'rutas en uso, sus archivos podrían haber sido puestos en cuarentena '
      'por error): ${decodeFailures.length}',
    );
    for (final failure in decodeFailures) {
      debugPrint(
        '  tabla=${failure.table} id=${failure.rowId} valorCrudo=${failure.rawValue}',
      );
    }
    debugPrint('=========================================================');
  }
}
