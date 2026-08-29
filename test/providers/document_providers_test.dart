// Pruebas de DocumentsNotifier: la orquestación datos + archivo es código
// NUEVO (antes vivía inline en add_edit_document_screen.dart /
// documents_screen.dart, y ni siquiera limpiaba el archivo reemplazado en
// una edición). A diferencia de deworming_providers_test.dart/
// vaccination_providers_test.dart, acá el propio notifier llama a
// ImageStorageService.saveImageIfNeeded -no la pantalla-, que depende de
// getApplicationDocumentsDirectory(): hace falta mockear
// PathProviderPlatform apuntando a un directorio temporal real (mismo
// patrón que data_backup_service_pet_fields_test.dart), combinado con
// archivos TEMPORALES REALES en disco para las aserciones de limpieza y el
// repository fake para los datos.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:pet_pal/models/document.dart';
import 'package:pet_pal/providers/document_providers.dart';
import 'package:pet_pal/repositories/document_repository.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsDir);

  final Directory documentsDir;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsDir.path;
}

class _FakeDocumentRepository implements DocumentRepository {
  _FakeDocumentRepository(this.records, {this.throwOnUpdate = false});

  final List<Document> records;
  final bool throwOnUpdate;

  @override
  Future<List<Document>> getDocumentsForPet(String petId) async {
    return records.where((r) => r.petId == petId).toList();
  }

  @override
  Future<void> insertDocument(Document document) async {
    records.add(document);
  }

  @override
  Future<void> updateDocument(Document document) async {
    if (throwOnUpdate) {
      throw Exception('fallo simulado al persistir el documento');
    }
    final index = records.indexWhere((r) => r.id == document.id);
    if (index != -1) records[index] = document;
  }

  @override
  Future<void> deleteDocument(String id) async {
    records.removeWhere((r) => r.id == id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRootDir;
  late Directory documentsDir; // simula getApplicationDocumentsDirectory()
  late Directory rawFilesDir; // simula archivos recién elegidos por el usuario, fuera de petpal_files/

  setUp(() async {
    tempRootDir = await Directory.systemTemp.createTemp('document_providers_test_');
    documentsDir = Directory(p.join(tempRootDir.path, 'documents'))..createSync(recursive: true);
    rawFilesDir = Directory(p.join(tempRootDir.path, 'raw'))..createSync(recursive: true);
    PathProviderPlatform.instance = _FakePathProvider(documentsDir);
  });

  tearDown(() async {
    try {
      if (await tempRootDir.exists()) {
        await tempRootDir.delete(recursive: true);
      }
    } catch (_) {
      // Mejor esfuerzo: no crítico para el resultado de la prueba.
    }
  });

  File makeRawFile(String name, String content) {
    final file = File(p.join(rawFilesDir.path, name));
    file.writeAsStringSync(content);
    return file;
  }

  ProviderContainer buildContainer(List<Document> records, {bool throwOnUpdate = false}) {
    final container = ProviderContainer(
      overrides: [
        documentRepositoryProvider.overrideWithValue(
          _FakeDocumentRepository(records, throwOnUpdate: throwOnUpdate),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('DocumentsNotifier.addDocument', () {
    test(
      'guarda el archivo crudo en almacenamiento permanente y persiste el registro con la ruta final',
      () async {
        final raw = makeRawFile('receta.pdf', 'contenido');
        final records = <Document>[];
        final container = buildContainer(records);

        await container.read(documentsProvider('pet-1').notifier).addDocument(
              petId: 'pet-1',
              categoria: 'Receta',
              titulo: 'Receta antibiótico',
              fecha: DateTime(2026, 1, 1),
              rawFilePath: raw.path,
            );

        expect(records, hasLength(1));
        final saved = records.single;
        expect(
          saved.filePath,
          isNot(raw.path),
          reason: 'debe copiarse a almacenamiento permanente, no apuntar al archivo crudo original',
        );
        expect(File(saved.filePath).existsSync(), isTrue);
        expect(p.normalize(saved.filePath), contains(p.join('petpal_files', 'documents')));
        // El archivo crudo original no se toca: solo se copia.
        expect(raw.existsSync(), isTrue);
      },
    );
  });

  group('DocumentsNotifier.updateDocument - limpieza de archivos huérfanos', () {
    test('reemplazar el archivo borra el viejo y conserva el nuevo', () async {
      final container = buildContainer([]);
      final notifier = container.read(documentsProvider('pet-1').notifier);

      final rawOld = makeRawFile('old.pdf', 'old');
      await notifier.addDocument(
        petId: 'pet-1',
        categoria: 'Receta',
        titulo: 'Doc',
        fecha: DateTime(2026, 1, 1),
        rawFilePath: rawOld.path,
      );
      final original = (await container.read(documentsProvider('pet-1').future)).single;
      final String oldSavedPath = original.filePath;

      final rawNew = makeRawFile('new.pdf', 'new');
      final draft = Document(
        id: original.id,
        petId: original.petId,
        categoria: original.categoria,
        titulo: original.titulo,
        fecha: original.fecha,
        filePath: rawNew.path,
        notas: original.notas,
      );

      await notifier.updateDocument(original, draft);

      expect(
        File(oldSavedPath).existsSync(),
        isFalse,
        reason: 'el archivo reemplazado debe limpiarse, no quedar huérfano',
      );

      final updated = (await container.read(documentsProvider('pet-1').future)).single;
      expect(File(updated.filePath).existsSync(), isTrue);
      expect(updated.filePath, isNot(oldSavedPath));
    });

    test('NO borra el archivo si la ruta no cambió', () async {
      final container = buildContainer([]);
      final notifier = container.read(documentsProvider('pet-1').notifier);

      final raw = makeRawFile('doc.pdf', 'data');
      await notifier.addDocument(
        petId: 'pet-1',
        categoria: 'Receta',
        titulo: 'Doc',
        fecha: DateTime(2026, 1, 1),
        rawFilePath: raw.path,
      );
      final original = (await container.read(documentsProvider('pet-1').future)).single;

      // El usuario no toca el archivo: la pantalla reenvía la misma ruta ya
      // guardada (comportamiento real de add_edit_document_screen.dart al
      // editar sin volver a elegir archivo).
      final draft = Document(
        id: original.id,
        petId: original.petId,
        categoria: original.categoria,
        titulo: 'Doc (título editado)',
        fecha: original.fecha,
        filePath: original.filePath,
        notas: original.notas,
      );

      await notifier.updateDocument(original, draft);

      expect(
        File(original.filePath).existsSync(),
        isTrue,
        reason: 'no debe borrar un archivo que el registro sigue usando '
            '-el bug contrario sería peor que el huérfano que se está arreglando',
      );
    });

    test('deleteDocument borra el archivo y el registro', () async {
      final container = buildContainer([]);
      final notifier = container.read(documentsProvider('pet-1').notifier);

      final raw = makeRawFile('doc.pdf', 'data');
      await notifier.addDocument(
        petId: 'pet-1',
        categoria: 'Receta',
        titulo: 'Doc',
        fecha: DateTime(2026, 1, 1),
        rawFilePath: raw.path,
      );
      final original = (await container.read(documentsProvider('pet-1').future)).single;

      await notifier.deleteDocument(original);

      expect(File(original.filePath).existsSync(), isFalse);
      expect(await container.read(documentsProvider('pet-1').future), isEmpty);
    });

    test(
      'si la escritura falla, el archivo viejo NO se borra (evita romper una referencia real)',
      () async {
        final rawOld = makeRawFile('old.pdf', 'old');
        final original = Document(
          petId: 'pet-1',
          categoria: 'Receta',
          titulo: 'Doc',
          fecha: DateTime(2026, 1, 1),
          filePath: rawOld.path,
        );
        final container = buildContainer([original], throwOnUpdate: true);
        final notifier = container.read(documentsProvider('pet-1').notifier);

        final rawNew = makeRawFile('new.pdf', 'new');
        final draft = Document(
          id: original.id,
          petId: original.petId,
          categoria: original.categoria,
          titulo: original.titulo,
          fecha: original.fecha,
          filePath: rawNew.path,
          notas: original.notas,
        );

        await expectLater(
          () => notifier.updateDocument(original, draft),
          throwsException,
        );

        expect(
          File(rawOld.path).existsSync(),
          isTrue,
          reason: 'la fila vigente en la base sigue siendo la vieja (con la ruta vieja); '
              'borrarla en este punto rompería una referencia real, no dejaría solo un huérfano',
        );
      },
    );
  });
}
