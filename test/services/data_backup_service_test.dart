// Prueba del mecanismo de cifrado que DataBackupService usa para el ZIP
// de backup (ZipEncoder/ZipDecoder con password, soportado nativamente por
// el paquete `archive` ^3.6.1 vía AES).
//
// DataBackupService.exportAllData/importAllData mezclan esta lógica con
// I/O de plataforma (path_provider para el directorio temporal,
// share_plus para compartir el archivo) que no tiene mock en este repo
// -mismo motivo por el que csv_export_service.dart tampoco tiene test de
// servicio completo (ver test/utils/csv_export_generator_test.dart)-. Por
// eso se prueba acá el mecanismo de cifrado en sí, que es la lógica nueva
// de esta fase, en vez de encadenar getTemporaryDirectory()/Share.shareXFiles.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _encryptedZipWith(String password, String content) {
  final archive = Archive();
  final bytes = Uint8List.fromList(utf8.encode(content));
  archive.addFile(ArchiveFile('backup.json', bytes.length, bytes));
  return Uint8List.fromList(ZipEncoder(password: password).encode(archive)!);
}

void main() {
  group('Cifrado del backup (ZipEncoder/ZipDecoder con password)', () {
    test('export + import con la misma contraseña reproduce los datos originales', () {
      const password = 'mi-contraseña-segura';
      const originalContent = '{"version":2,"pets":[]}';

      final zipBytes = _encryptedZipWith(password, originalContent);
      final archive = ZipDecoder().decodeBytes(zipBytes, password: password);

      final backupJsonFile = archive.files.firstWhere((f) => f.name == 'backup.json');
      final decoded = utf8.decode(backupJsonFile.content as List<int>);

      expect(decoded, originalContent);
    });

    test('importar con una contraseña incorrecta falla de forma controlada', () {
      final zipBytes = _encryptedZipWith('contraseña-correcta', '{"version":2}');

      // decodeBytes en sí no dispara la verificación HMAC del AE-2 -eso pasa
      // recién al pedir el contenido descomprimido de un archivo-, así que
      // hay que forzarla con verify:true (falla en decodeBytes) o acceder a
      // backupJsonFile.content (falla ahí). data_backup_service.dart hace lo
      // segundo indirectamente al leer backup.json después de decodificar.
      expect(
        () => ZipDecoder().decodeBytes(
          zipBytes,
          password: 'contraseña-incorrecta',
          verify: true,
        ),
        throwsA(anything),
      );
    });

    test('un ZIP cifrado no expone el contenido en texto plano', () {
      const secret = 'información médica sensible';
      final zipBytes = _encryptedZipWith('clave', secret);

      final rawText = latin1.decode(zipBytes, allowInvalid: true);
      expect(rawText.contains(secret), isFalse);
    });
  });
}
