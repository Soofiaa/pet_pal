// Pruebas de DocumentRepository: confirma que delega correctamente en
// DatabaseHelper. Deliberadamente NO usa archivos reales ni
// ImageStorageService -el repository es solo acceso a datos, no gestiona
// el archivo adjunto; eso vive en DocumentsNotifier y se prueba aparte en
// test/providers/document_providers_test.dart-.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/document.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/repositories/document_repository.dart';

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

  late DocumentRepository repository;

  setUp(() {
    repository = DocumentRepository(DatabaseHelper());
  });

  group('DocumentRepository', () {
    test('insertDocument + getDocumentsForPet devuelven lo insertado', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      await repository.insertDocument(Document(
        petId: pet.id,
        categoria: 'Receta',
        titulo: 'Análisis A',
        fecha: DateTime(2026, 1, 1),
        filePath: '/tmp/a.pdf',
      ));
      await repository.insertDocument(Document(
        petId: pet.id,
        categoria: 'Cirugía',
        titulo: 'Análisis B',
        fecha: DateTime(2026, 2, 1),
        filePath: '/tmp/b.pdf',
        notas: 'Post-operatorio',
      ));

      final records = await repository.getDocumentsForPet(pet.id);
      expect(records, hasLength(2));
    });

    test('getDocumentsForPet no devuelve registros de otra mascota', () async {
      final dbHelper = DatabaseHelper();
      final petA = await _insertSamplePet(dbHelper);
      final petB = await _insertSamplePet(dbHelper);

      await repository.insertDocument(Document(
        petId: petA.id,
        categoria: 'Receta',
        titulo: 'Doc A',
        fecha: DateTime(2026, 1, 1),
        filePath: '/tmp/a.pdf',
      ));
      await repository.insertDocument(Document(
        petId: petB.id,
        categoria: 'Receta',
        titulo: 'Doc B',
        fecha: DateTime(2026, 1, 1),
        filePath: '/tmp/b.pdf',
      ));

      final recordsA = await repository.getDocumentsForPet(petA.id);
      expect(recordsA, hasLength(1));
      expect(recordsA.first.petId, petA.id);
    });

    test('updateDocument actualiza el registro existente', () async {
      final pet = await _insertSamplePet(DatabaseHelper());
      const id = 'document-1';

      await repository.insertDocument(Document(
        id: id,
        petId: pet.id,
        categoria: 'Receta',
        titulo: 'Análisis A',
        fecha: DateTime(2026, 1, 1),
        filePath: '/tmp/a.pdf',
      ));

      final inserted = (await repository.getDocumentsForPet(pet.id)).first;
      await repository.updateDocument(
        inserted.copyWith(titulo: 'Análisis A (actualizado)'),
      );

      final updated = (await repository.getDocumentsForPet(pet.id)).first;
      expect(updated.titulo, 'Análisis A (actualizado)');
    });

    test('deleteDocument elimina el registro', () async {
      final pet = await _insertSamplePet(DatabaseHelper());

      await repository.insertDocument(Document(
        id: 'document-2',
        petId: pet.id,
        categoria: 'Receta',
        titulo: 'Doc',
        fecha: DateTime(2026, 1, 1),
        filePath: '/tmp/a.pdf',
      ));

      await repository.deleteDocument('document-2');

      expect(await repository.getDocumentsForPet(pet.id), isEmpty);
    });
  });
}
