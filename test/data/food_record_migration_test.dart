// Prueba de la migración v29 de food_records (agrega isOngoing como campo
// real, ver database_helper.dart::_onUpgrade). Va en un archivo propio -y no
// en database_helper_test.dart- porque necesita sembrar el archivo .db físico
// con el esquema viejo (v28, sin isOngoing) *antes* de que DatabaseHelper lo
// abra por primera vez en este isolate; database_helper_test.dart y otros
// archivos que usan sqflite_common_ffi abren la base ya en la versión
// vigente a través de DatabaseHelper() antes de cada test, así que compartir
// el archivo mezclaría ambos escenarios entre corridas de un mismo isolate.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pet_pal/data/database_helper.dart';

void main() {
  late Directory tempDbDir;
  late String dbPath;

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDbDir = await Directory.systemTemp.createTemp('pet_pal_test_migration_db_');
    // ignore: deprecated_member_use
    await databaseFactory.setDatabasesPath(tempDbDir.path);
    dbPath = join(tempDbDir.path, 'pet_pal_v2.db');
  });

  tearDown(() async {
    try {
      if (await tempDbDir.exists()) {
        await tempDbDir.delete(recursive: true);
      }
    } catch (_) {
      // Se ignora: el SO limpia temporales eventualmente.
    }
  });

  test(
    'migración v29: filas con endDate NULL quedan isOngoing=1, filas con '
    'endDate seteado quedan isOngoing=0 -sin cambiar el significado de '
    'ningún registro creado antes de este campo-',
    () async {
      // 1. Sembrar el archivo .db en el esquema viejo (v28, sin isOngoing),
      // con una fila "sigue comiendo" (endDate null) y otra "dejó de
      // comerlo en fecha conocida" (endDate seteado) -exactamente los dos
      // casos que el getter viejo (endDate == null) distinguía-.
      final seedDb = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 28,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE food_records(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                petId TEXT,
                foodName TEXT NOT NULL,
                startDate TEXT,
                endDate TEXT,
                notes TEXT NOT NULL DEFAULT ''
              )
            ''');
          },
        ),
      );
      await seedDb.insert('food_records', {
        'petId': 'pet-1',
        'foodName': 'Croquetas (sigue comiendo)',
        'startDate': DateTime(2026, 1, 1).toIso8601String(),
        'endDate': null,
        'notes': '',
      });
      await seedDb.insert('food_records', {
        'petId': 'pet-1',
        'foodName': 'Pollo hervido (ya no)',
        'startDate': DateTime(2025, 1, 1).toIso8601String(),
        'endDate': DateTime(2025, 6, 1).toIso8601String(),
        'notes': '',
      });
      await seedDb.close();

      // 2. Abrir a través de DatabaseHelper -primera vez en este isolate-,
      // lo que dispara _onUpgrade(db, 28, 29) con el código real de
      // producción, no una simulación.
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final rows = await db.query('food_records', orderBy: 'id ASC');
      expect(rows, hasLength(2));

      final ongoingRow = rows.firstWhere((r) => r['foodName'] == 'Croquetas (sigue comiendo)');
      expect(ongoingRow['endDate'], isNull);
      expect(ongoingRow['isOngoing'], 1);

      final stoppedRow = rows.firstWhere((r) => r['foodName'] == 'Pollo hervido (ya no)');
      expect(stoppedRow['endDate'], isNotNull);
      expect(stoppedRow['isOngoing'], 0);
    },
  );
}
