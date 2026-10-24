// La cuarentena de huérfanos (petpal_files/_huerfanos_*) debe poder medirse
// y borrarse desde la app, sin tocar nunca los archivos que sí están en uso.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:pet_pal/services/orphan_cleanup_service.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsDir);

  final Directory documentsDir;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsDir.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory filesDir;

  File write(String relative, int bytes) {
    final file = File(p.join(filesDir.path, relative))
      ..createSync(recursive: true)
      ..writeAsBytesSync(List.filled(bytes, 1));
    return file;
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('orphan_quarantine_test_');
    final documents = Directory(p.join(root.path, 'documents'))..createSync();
    filesDir = Directory(p.join(documents.path, 'petpal_files'))..createSync();
    PathProviderPlatform.instance = _FakePathProvider(documents);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('sin carpeta de cuarentena el resumen es vacío', () async {
    write('foto_en_uso.jpg', 10);

    final summary = await OrphanCleanupService.quarantineSummary();

    expect(summary.fileCount, 0);
    expect(summary.totalBytes, 0);
  });

  test('el resumen cuenta archivos y bytes de todas las cuarentenas', () async {
    write('_huerfanos_1/a.jpg', 100);
    write('_huerfanos_1/b.jpg', 50);
    write('_huerfanos_2/c.pdf', 25);
    write('foto_en_uso.jpg', 999);

    final summary = await OrphanCleanupService.quarantineSummary();

    expect(summary.fileCount, 3);
    expect(summary.totalBytes, 175);
  });

  test('con alguna fila de JSON corrupto NO se mueve nada a cuarentena', () {
    final corrupt = [
      const JsonDecodeFailure(table: 'notes', rowId: 'n1', rawValue: '{roto'),
    ];
    expect(OrphanCleanupService.canQuarantine(corrupt), isFalse);
  });

  test('sin filas corruptas sí se puede mover a cuarentena', () {
    expect(OrphanCleanupService.canQuarantine(const []), isTrue);
  });

  test('borrar la cuarentena elimina solo _huerfanos_* y conserva lo demás', () async {
    write('_huerfanos_1/a.jpg', 100);
    write('_huerfanos_2/c.pdf', 25);
    final enUso = write('foto_en_uso.jpg', 999);
    final enSubcarpeta = write('mascotas/luna.jpg', 20);

    final deleted = await OrphanCleanupService.deleteQuarantine();

    expect(deleted, 2);
    expect(Directory(p.join(filesDir.path, '_huerfanos_1')).existsSync(), isFalse);
    expect(Directory(p.join(filesDir.path, '_huerfanos_2')).existsSync(), isFalse);
    expect(enUso.existsSync(), isTrue);
    expect(enSubcarpeta.existsSync(), isTrue);
    expect((await OrphanCleanupService.quarantineSummary()).fileCount, 0);
  });
}
