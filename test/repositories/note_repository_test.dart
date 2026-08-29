// Pruebas de NoteRepository: confirma que delega correctamente en
// DatabaseHelper. Deliberadamente NO usa archivos reales ni
// ImageStorageService -el repository es solo acceso a datos, no gestiona
// photoPaths; eso vive en NotesNotifier y se prueba aparte en
// test/providers/note_providers_test.dart-.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/note.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/repositories/note_repository.dart';

Future<Pet> _insertSamplePet(DatabaseHelper dbHelper) async {
  final pet = Pet(
    name: 'Firulais',
    species: 'Perro',
    breed: 'Mestizo',
    dob: DateTime(2020, 1, 1),
    color: 'Marrón',
  );
  await dbHelper.insertPet(pet);
  return pet;
}

void main() {
  late Directory tempDbDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Ruta propia de este archivo: evita que este y otros archivos que
    // también usan sqflite_common_ffi compartan el mismo pet_pal_v2.db
    // físico cuando corren en paralelo -> "database is locked".
    tempDbDir = await Directory.systemTemp.createTemp('pet_pal_test_db_');
    // ignore: deprecated_member_use
    await databaseFactory.setDatabasesPath(tempDbDir.path);
  });

  tearDownAll(() async {
    // Mejor esfuerzo, no crítico: DatabaseHelper es un singleton que nunca
    // cierra su conexión, así que en Windows el archivo .db puede seguir
    // con un handle abierto acá y el borrado fallar (PathAccessException).
    try {
      if (await tempDbDir.exists()) {
        await tempDbDir.delete(recursive: true);
      }
    } catch (_) {
      // Se ignora: el SO limpia temporales eventualmente.
    }
  });

  setUp(() async {
    await DatabaseHelper().deleteAllData();
  });

  late NoteRepository repository;

  setUp(() {
    repository = NoteRepository(DatabaseHelper());
  });

  group('NoteRepository', () {
    test('insertNote + getNotesForPet devuelven lo insertado, con photoPaths', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      await repository.insertNote(Note(
        petId: pet.id,
        title: 'Nota A',
        content: 'Contenido A',
        date: DateTime(2026, 1, 1),
        photoPaths: const ['/tmp/a1.jpg', '/tmp/a2.jpg'],
      ));
      await repository.insertNote(Note(
        petId: pet.id,
        title: 'Nota B',
        content: 'Contenido B',
        date: DateTime(2026, 2, 1),
      ));

      final records = await repository.getNotesForPet(pet.id);
      expect(records, hasLength(2));
      final noteA = records.firstWhere((n) => n.title == 'Nota A');
      expect(noteA.photoPaths, ['/tmp/a1.jpg', '/tmp/a2.jpg']);
      final noteB = records.firstWhere((n) => n.title == 'Nota B');
      expect(noteB.photoPaths, isEmpty);
    });

    test('getNotesForPet no devuelve registros de otra mascota', () async {
      final dbHelper = DatabaseHelper();
      final petA = await _insertSamplePet(dbHelper);
      final petB = await _insertSamplePet(dbHelper);

      await repository.insertNote(Note(
        petId: petA.id,
        title: 'Nota A',
        content: 'Contenido A',
        date: DateTime(2026, 1, 1),
      ));
      await repository.insertNote(Note(
        petId: petB.id,
        title: 'Nota B',
        content: 'Contenido B',
        date: DateTime(2026, 1, 1),
      ));

      final recordsA = await repository.getNotesForPet(petA.id);
      expect(recordsA, hasLength(1));
      expect(recordsA.first.petId, petA.id);
    });

    test('updateNote actualiza el registro existente, incluyendo photoPaths', () async {
      final pet = await _insertSamplePet(DatabaseHelper());
      const id = 'note-1';

      await repository.insertNote(Note(
        id: id,
        petId: pet.id,
        title: 'Nota A',
        content: 'Contenido A',
        date: DateTime(2026, 1, 1),
        photoPaths: const ['/tmp/a1.jpg'],
      ));

      final inserted = (await repository.getNotesForPet(pet.id)).first;
      await repository.updateNote(
        inserted.copyWith(title: 'Nota A (actualizada)', photoPaths: const ['/tmp/a1.jpg', '/tmp/a2.jpg']),
      );

      final updated = (await repository.getNotesForPet(pet.id)).first;
      expect(updated.title, 'Nota A (actualizada)');
      expect(updated.photoPaths, ['/tmp/a1.jpg', '/tmp/a2.jpg']);
    });

    test('deleteNote elimina el registro', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      await repository.insertNote(Note(
        id: 'note-2',
        petId: pet.id,
        title: 'Nota',
        content: 'Contenido',
        date: DateTime(2026, 1, 1),
      ));

      await repository.deleteNote('note-2');

      expect(await repository.getNotesForPet(pet.id), isEmpty);
    });
  });
}
