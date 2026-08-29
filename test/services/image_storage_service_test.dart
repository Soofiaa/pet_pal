// Prueba de ImageStorageService: reproduce el escenario exacto encontrado
// al escribir note_providers_test.dart (Fase 2 de la migración de Notas).
// El naming scheme viejo de saveImage era
// '${milisegundos}_${tamañoEnBytes}${extensión}': dos archivos del MISMO
// tamaño guardados en sucesión inmediata por saveImagesIfNeeded (el mismo
// método que usa NotesNotifier para la lista de fotos de una nota, y
// VaccinationsNotifier para las fotos extra) podían caer en el mismo
// milisegundo en un runner rápido -pasó en el de GitHub Actions, nunca en
// Windows local- y generar el mismo nombre; File.copy pisaba la primera
// copia en silencio, sin avisar. Con un uuid como componente de unicidad,
// la colisión ya no es posible sin importar tamaño ni timing.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:pet_pal/services/image_storage_service.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsDir);

  final Directory documentsDir;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsDir.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRootDir;
  late Directory documentsDir; // simula getApplicationDocumentsDirectory()
  late Directory rawFilesDir; // simula archivos recién elegidos por el usuario

  setUp(() async {
    tempRootDir = await Directory.systemTemp.createTemp('image_storage_service_test_');
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

  group('ImageStorageService.saveImagesIfNeeded - unicidad de nombre', () {
    test(
      'dos archivos del mismo tamaño guardados en sucesión inmediata no colisionan',
      () async {
        final raw1 = makeRawFile('foto1.jpg', 'contenido-igual');
        final raw2 = makeRawFile('foto2.jpg', 'contenido-igual');
        expect(
          raw1.lengthSync(),
          raw2.lengthSync(),
          reason: 'mismo tamaño en bytes: el criterio exacto que colisionaba con el naming scheme viejo',
        );

        final List<String> savedPaths =
            await ImageStorageService.saveImagesIfNeeded([raw1.path, raw2.path], 'notes');

        expect(savedPaths, hasLength(2));
        expect(
          savedPaths[0],
          isNot(savedPaths[1]),
          reason: 'dos guardados de archivos del mismo tamaño no deben pisarse entre sí',
        );
        expect(File(savedPaths[0]).existsSync(), isTrue);
        expect(File(savedPaths[1]).existsSync(), isTrue);
        // Si hubieran colisionado, las dos rutas apuntarían al mismo
        // archivo físico y ambas lecturas devolverían el mismo File.
        expect(File(savedPaths[0]).readAsStringSync(), 'contenido-igual');
        expect(File(savedPaths[1]).readAsStringSync(), 'contenido-igual');
      },
    );

    test(
      'guardar muchos archivos del mismo tamaño en sucesión produce rutas todas distintas',
      () async {
        final List<String> rawPaths =
            List.generate(20, (i) => makeRawFile('foto_$i.jpg', 'contenido-igual').path);

        final List<String> savedPaths =
            await ImageStorageService.saveImagesIfNeeded(rawPaths, 'notes');

        expect(savedPaths, hasLength(20));
        expect(savedPaths.toSet(), hasLength(20), reason: 'no debe haber dos rutas iguales');
        for (final path in savedPaths) {
          expect(File(path).existsSync(), isTrue);
        }
      },
    );
  });
}
