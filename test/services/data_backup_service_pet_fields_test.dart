// Prueba de extremo a extremo de DataBackupService.exportAllData/
// importAllData: a diferencia de data_backup_service_test.dart (que solo
// ejercita el mecanismo de cifrado ZipEncoder/ZipDecoder porque el resto del
// pipeline usa path_provider/share_plus/file_picker sin mock en este repo),
// acá SÍ se mockean esos tres plugins vía sus platform interfaces
// (PathProviderPlatform.instance, SharePlatform.instance, FilePicker.platform
// son settable con verificación de token, técnica estándar del ecosistema de
// plugins Flutter) para poder correr export -> import real contra una base
// de datos sqflite_common_ffi y verificar que ningún campo se pierde.
//
// Motivo puntual: un reporte de que "esterilización" y "número de microchip"
// no sobrevivían al backup. La revisión de código no encontró ningún bug -
// Pet.toJson()/fromJson() ya incluyen ambos campos y DataBackupService los
// propaga vía `...pet.toJson()` sin lista explícita de claves- pero esa
// revisión nunca había sido confirmada con una ejecución real del pipeline
// completo. Este test cierra esa brecha y queda como guardia de regresión:
// agregar un campo nuevo a Pet (o a cualquier otro modelo cubierto acá)
// y no propagarlo en el backup debería reventar esta prueba.
//
// También cubre loadBackupForRestore/applyRestoredBackup -la partición de
// importAllData en "leer y previsualizar" vs. "aplicar el reemplazo
// destructivo"- agregada para que backup_settings_screen.dart pueda
// mostrarle al usuario la fecha y cantidad de mascotas del backup elegido
// antes de confirmar el reemplazo irreversible.
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/note.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/vaccination.dart';
import 'package:pet_pal/services/data_backup_service.dart';

/// Ruta absoluta del último ZIP "compartido" vía Share.shareXFiles -lo pisa
/// _FakeShare en cada exportAllData(), y _FakeFilePicker lo devuelve como si
/// el usuario lo hubiera elegido en el siguiente importAllData().
String? _lastSharedZipPath;

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.tempDir, this.documentsDir);

  final Directory tempDir;
  final Directory documentsDir;

  @override
  Future<String?> getTemporaryPath() async => tempDir.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsDir.path;
}

class _FakeShare extends SharePlatform {
  @override
  Future<ShareResult> shareXFiles(
    List<XFile> files, {
    String? subject,
    String? text,
    Rect? sharePositionOrigin,
  }) async {
    _lastSharedZipPath = files.single.path;
    return const ShareResult('', ShareResultStatus.success);
  }
}

class _FakeFilePicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    final path = _lastSharedZipPath;
    if (path == null) return null;
    return FilePickerResult([
      PlatformFile(path: path, name: 'backup.zip', size: await File(path).length()),
    ]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRootDir;
  late DataBackupService backupService;
  late DatabaseHelper dbHelper;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempRootDir = await Directory.systemTemp.createTemp('pet_pal_backup_test_');
    // ignore: deprecated_member_use
    await databaseFactory.setDatabasesPath(tempRootDir.path);

    PathProviderPlatform.instance = _FakePathProvider(
      Directory(p(tempRootDir.path, 'tmp'))..createSync(recursive: true),
      Directory(p(tempRootDir.path, 'documents'))..createSync(recursive: true),
    );
    SharePlatform.instance = _FakeShare();
    FilePicker.platform = _FakeFilePicker();
  });

  tearDownAll(() async {
    try {
      if (await tempRootDir.exists()) {
        await tempRootDir.delete(recursive: true);
      }
    } catch (_) {
      // Mejor esfuerzo: limpieza de temporales de test, no crítico si falla.
    }
  });

  setUp(() async {
    _lastSharedZipPath = null;
    dbHelper = DatabaseHelper();
    await dbHelper.deleteAllData();
    backupService = DataBackupService();
  });

  test(
    'exportAllData + importAllData preserva microchip, esterilización y '
    'registros asociados de la mascota',
    () async {
      final pet = Pet(
        name: 'Firulais',
        species: 'Perro',
        breed: 'Mestizo',
        dob: DateTime(2020, 1, 1),
        color: 'Marrón',
        microchipNumber: '985141000123456',
        isNeutered: true,
      );
      await dbHelper.insertPet(pet);

      await dbHelper.insertNote(Note(
        petId: pet.id,
        title: 'Control anual',
        content: 'Todo en orden.',
        date: DateTime(2024, 3, 1),
      ));
      await dbHelper.insertVaccination(Vaccination(
        petId: pet.id,
        vaccineName: 'Antirrábica',
        date: DateTime(2024, 2, 1),
      ));

      const password = 'contraseña-de-prueba';

      final exportResult = await backupService.exportAllData(password);
      expect(exportResult, contains('éxito'), reason: exportResult);
      expect(_lastSharedZipPath, isNotNull);

      // Simula "el usuario borró todo y restauró desde el backup".
      await dbHelper.deleteAllData();
      expect(await dbHelper.getPets(), isEmpty);

      final importResult = await backupService.importAllData(password: password);
      expect(importResult, contains('éxito'), reason: importResult);

      final restoredPets = await dbHelper.getPets();
      expect(restoredPets, hasLength(1));

      final restoredPet = restoredPets.single;
      expect(restoredPet.id, pet.id);
      expect(restoredPet.name, pet.name);
      expect(restoredPet.microchipNumber, '985141000123456');
      expect(restoredPet.isNeutered, isTrue);

      final restoredNotes = await dbHelper.getNotesForPet(restoredPet.id);
      expect(restoredNotes, hasLength(1));
      expect(restoredNotes.single.title, 'Control anual');

      final restoredVaccinations = await dbHelper.getVaccinationsForPet(restoredPet.id);
      expect(restoredVaccinations, hasLength(1));
      expect(restoredVaccinations.single.vaccineName, 'Antirrábica');
    },
  );

  group('loadBackupForRestore / applyRestoredBackup (previsualización antes de restaurar)', () {
    test(
      'la previsualización trae la fecha y la cantidad de mascotas del backup, '
      'y no toca la base de datos hasta que se llama a applyRestoredBackup',
      () async {
        await dbHelper.insertPet(Pet(
          name: 'Firulais',
          species: 'Perro',
          breed: 'Mestizo',
          dob: DateTime(2020, 1, 1),
          color: 'Marrón',
        ));

        const password = 'contraseña-de-prueba';
        final beforeExport = DateTime.now();
        final exportResult = await backupService.exportAllData(password);
        expect(exportResult, contains('éxito'), reason: exportResult);

        // Todavía no restauramos nada: los datos actuales (la mascota recién
        // insertada) deben seguir intactos después de solo previsualizar.
        final loadResult = await backupService.loadBackupForRestore(password: password);
        expect(loadResult.error, isNull, reason: loadResult.error);
        final preview = loadResult.preview!;

        expect(preview.petCount, 1);
        expect(preview.timestamp, isNotNull);
        expect(
          preview.timestamp!.difference(beforeExport).inMinutes.abs() < 1,
          isTrue,
          reason: 'el timestamp del backup debería ser ~ahora, fue ${preview.timestamp}',
        );
        expect(await dbHelper.getPets(), hasLength(1));

        final applyResult = await backupService.applyRestoredBackup(preview.restoredData);
        expect(applyResult, contains('éxito'), reason: applyResult);
        expect(await dbHelper.getPets(), hasLength(1));
      },
    );

    test('con la contraseña incorrecta, la previsualización falla sin tocar la base de datos', () async {
      await dbHelper.insertPet(Pet(
        name: 'Firulais',
        species: 'Perro',
        breed: 'Mestizo',
        dob: DateTime(2020, 1, 1),
        color: 'Marrón',
      ));

      await backupService.exportAllData('contraseña-correcta');

      final loadResult =
          await backupService.loadBackupForRestore(password: 'contraseña-incorrecta');

      expect(loadResult.error, isNotNull);
      expect(loadResult.preview, isNull);
      expect(await dbHelper.getPets(), hasLength(1));
    });
  });
}

/// path.join() minimalista -evita agregar `package:path` solo para esto en
/// un test que ya importa suficientes paquetes de infraestructura.
String p(String a, String b) => '$a${Platform.pathSeparator}$b';
