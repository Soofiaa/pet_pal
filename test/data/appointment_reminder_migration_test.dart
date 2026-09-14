// Prueba de la migración v30 de appointments (agrega reminderDaysBefore,
// ver database_helper.dart::_onUpgrade). Va en un archivo propio -y no en
// database_helper_test.dart- porque necesita sembrar el archivo .db físico
// con el esquema viejo (v29, sin reminderDaysBefore) *antes* de que
// DatabaseHelper lo abra por primera vez en este isolate; mismo motivo que
// food_record_migration_test.dart.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/appointment.dart';

void main() {
  late Directory tempDbDir;
  late String dbPath;

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDbDir = await Directory.systemTemp.createTemp('pet_pal_test_appt_migration_db_');
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
    'migración v30: una cita creada en el esquema viejo (sin '
    'reminderDaysBefore) recibe el default de 1 día, no queda con el campo '
    'nulo',
    () async {
      // 1. Sembrar el archivo .db en el esquema viejo (v29, sin
      // reminderDaysBefore), con una cita ya existente.
      final seedDb = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 29,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE appointments(
                id TEXT PRIMARY KEY,
                petId TEXT,
                dateTime TEXT,
                title TEXT,
                description TEXT,
                location TEXT,
                type TEXT,
                isCompleted INTEGER NOT NULL DEFAULT 0
              )
            ''');
          },
        ),
      );
      await seedDb.insert('appointments', {
        'id': 'cita-vieja-1',
        'petId': 'pet-1',
        'dateTime': DateTime(2030, 1, 1, 10, 0).toIso8601String(),
        'title': 'Control preexistente',
        'description': null,
        'location': null,
        'type': null,
        'isCompleted': 0,
      });
      await seedDb.close();

      // 2. Abrir a través de DatabaseHelper -primera vez en este isolate-,
      // lo que dispara _onUpgrade(db, 29, 30) con el código real de
      // producción, no una simulación.
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final rows = await db.query('appointments', where: 'id = ?', whereArgs: ['cita-vieja-1']);
      expect(rows, hasLength(1));
      expect(
        rows.single['reminderDaysBefore'],
        1,
        reason: 'las citas migradas desde el esquema viejo deben quedar con '
            'el default de 1 día, no nulas',
      );

      final appointment = Appointment.fromJson(rows.single);
      expect(appointment.reminderDaysBefore, 1);
    },
  );
}
