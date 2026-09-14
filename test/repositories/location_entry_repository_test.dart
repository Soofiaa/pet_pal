// Pruebas de LocationEntryRepository: confirma que delega correctamente en
// DatabaseHelper. A diferencia de otros repositories de la suite, el
// catálogo de ubicaciones no está asociado a ninguna mascota -no hace falta
// insertar un Pet primero-.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/location_entry.dart';
import 'package:pet_pal/repositories/location_entry_repository.dart';

void main() {
  late Directory tempDbDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDbDir = await Directory.systemTemp.createTemp('location_entry_repo_test_db_');
    // ignore: deprecated_member_use
    await databaseFactory.setDatabasesPath(tempDbDir.path);
  });

  tearDownAll(() async {
    try {
      if (await tempDbDir.exists()) {
        await tempDbDir.delete(recursive: true);
      }
    } catch (_) {
      // Mejor esfuerzo, no crítico: ver mismo comentario en database_helper_test.dart.
    }
  });

  setUp(() async {
    await DatabaseHelper().deleteAllData();
  });

  late LocationEntryRepository repository;

  setUp(() {
    repository = LocationEntryRepository(DatabaseHelper());
  });

  group('LocationEntryRepository', () {
    test('insertEntry + getEntries devuelven lo insertado, ordenado por nombre', () async {
      await repository.insertEntry(LocationEntry(id: 'e1', name: 'Zoológico', mapsUrl: ''));
      await repository.insertEntry(LocationEntry(id: 'e2', name: 'Alameda', mapsUrl: ''));

      final entries = await repository.getEntries();

      expect(entries, hasLength(2));
      expect(entries.map((e) => e.name).toList(), ['Alameda', 'Zoológico']);
    });

    test('updateEntry actualiza la entrada existente', () async {
      await repository.insertEntry(
        LocationEntry(id: 'e1', name: 'Veterinaria Vieja', mapsUrl: 'https://old'),
      );

      final inserted = (await repository.getEntries()).first;
      await repository.updateEntry(inserted.copyWith(name: 'Veterinaria Nueva', mapsUrl: 'https://new'));

      final updated = (await repository.getEntries()).first;
      expect(updated.name, 'Veterinaria Nueva');
      expect(updated.mapsUrl, 'https://new');
    });

    test('deleteEntry elimina la entrada', () async {
      await repository.insertEntry(LocationEntry(id: 'e1', name: 'Lugar A', mapsUrl: ''));

      await repository.deleteEntry('e1');

      expect(await repository.getEntries(), isEmpty);
    });
  });
}
