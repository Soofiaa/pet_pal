// Pruebas de NotesNotifier: la orquestación datos + archivos es código
// NUEVO (antes vivía inline en add_edit_note_screen.dart / notes_screen.dart,
// que ni copiaba fotos crudas a almacenamiento permanente en un alta
// -dependía de que la ruta del picker siguiera viva- ni borraba las fotos
// sacadas al editar). A diferencia de document_providers_test.dart, acá
// photoPaths es una LISTA: los tests de updateNote cubren el diff por Set
// (agregar sin tocar lo existente, sacar sin tocar lo que queda), y hay un
// grupo aparte para deleteNotes (borrado múltiple), incluyendo el
// comportamiento de fallo parcial (best-effort, sin rollback).
//
// Mismo mock de PathProviderPlatform que document_providers_test.dart,
// combinado con archivos TEMPORALES REALES en disco para las aserciones de
// limpieza y el repository fake para los datos.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:pet_pal/models/note.dart';
import 'package:pet_pal/providers/note_providers.dart';
import 'package:pet_pal/repositories/note_repository.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsDir);

  final Directory documentsDir;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsDir.path;
}

class _FakeNoteRepository implements NoteRepository {
  _FakeNoteRepository(this.records, {this.throwOnUpdate = false, this.failDeleteIds = const {}});

  final List<Note> records;
  final bool throwOnUpdate;
  final Set<String> failDeleteIds;

  @override
  Future<List<Note>> getNotesForPet(String petId) async {
    return records.where((r) => r.petId == petId).toList();
  }

  @override
  Future<void> insertNote(Note note) async {
    records.add(note);
  }

  @override
  Future<void> updateNote(Note note) async {
    if (throwOnUpdate) {
      throw Exception('fallo simulado al persistir la nota');
    }
    final index = records.indexWhere((r) => r.id == note.id);
    if (index != -1) records[index] = note;
  }

  @override
  Future<void> deleteNote(String id) async {
    if (failDeleteIds.contains(id)) {
      throw Exception('fallo simulado al borrar la nota $id');
    }
    records.removeWhere((r) => r.id == id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRootDir;
  late Directory documentsDir; // simula getApplicationDocumentsDirectory()
  late Directory rawFilesDir; // simula archivos recién elegidos por el usuario, fuera de petpal_files/

  setUp(() async {
    tempRootDir = await Directory.systemTemp.createTemp('note_providers_test_');
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

  ProviderContainer buildContainer(
    List<Note> records, {
    bool throwOnUpdate = false,
    Set<String> failDeleteIds = const {},
  }) {
    final container = ProviderContainer(
      overrides: [
        noteRepositoryProvider.overrideWithValue(
          _FakeNoteRepository(records, throwOnUpdate: throwOnUpdate, failDeleteIds: failDeleteIds),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('NotesNotifier.addNote', () {
    test(
      'guarda las fotos crudas en almacenamiento permanente y persiste el registro con las rutas finales',
      () async {
        final raw1 = makeRawFile('foto1.jpg', 'contenido1');
        final raw2 = makeRawFile('foto2.jpg', 'contenido2');
        final records = <Note>[];
        final container = buildContainer(records);

        await container.read(notesProvider('pet-1').notifier).addNote(
              petId: 'pet-1',
              title: 'Primera nota',
              content: 'Contenido',
              date: DateTime(2026, 1, 1),
              rawPhotoPaths: [raw1.path, raw2.path],
            );

        expect(records, hasLength(1));
        final saved = records.single;
        expect(saved.photoPaths, hasLength(2));
        for (final path in saved.photoPaths) {
          expect(File(path).existsSync(), isTrue);
          expect(p.normalize(path), contains(p.join('petpal_files', 'notes')));
        }
        // Los archivos crudos originales no se tocan: solo se copian.
        expect(raw1.existsSync(), isTrue);
        expect(raw2.existsSync(), isTrue);
      },
    );

    test('una nota sin fotos persiste photoPaths vacío', () async {
      final records = <Note>[];
      final container = buildContainer(records);

      await container.read(notesProvider('pet-1').notifier).addNote(
            petId: 'pet-1',
            title: 'Sin fotos',
            content: 'Contenido',
            date: DateTime(2026, 1, 1),
          );

      expect(records.single.photoPaths, isEmpty);
    });
  });

  group('NotesNotifier.updateNote - diff de photoPaths', () {
    test('agregar una foto nueva guarda la nueva y no toca la existente', () async {
      final container = buildContainer([]);
      final notifier = container.read(notesProvider('pet-1').notifier);

      final rawExisting = makeRawFile('existing.jpg', 'existing');
      await notifier.addNote(
        petId: 'pet-1',
        title: 'Nota',
        content: 'Contenido',
        date: DateTime(2026, 1, 1),
        rawPhotoPaths: [rawExisting.path],
      );
      final original = (await container.read(notesProvider('pet-1').future)).single;
      final String existingSavedPath = original.photoPaths.single;

      final rawNew = makeRawFile('new.jpg', 'new');
      final draft = Note(
        id: original.id,
        petId: original.petId,
        title: original.title,
        content: original.content,
        date: original.date,
        // La pantalla reenvía la ruta ya guardada tal cual (no la tocó) más
        // la ruta cruda nueva del picker.
        photoPaths: [existingSavedPath, rawNew.path],
      );

      await notifier.updateNote(original, draft);

      final updated = (await container.read(notesProvider('pet-1').future)).single;
      expect(updated.photoPaths, hasLength(2));
      expect(
        File(existingSavedPath).existsSync(),
        isTrue,
        reason: 'la foto que seguía presente en ambas listas no debe tocarse',
      );
      final String newSavedPath = updated.photoPaths.firstWhere((p) => p != existingSavedPath);
      expect(File(newSavedPath).existsSync(), isTrue);
    });

    test('sacar una foto la borra del disco sin tocar las que quedan', () async {
      final container = buildContainer([]);
      final notifier = container.read(notesProvider('pet-1').notifier);

      final raw1 = makeRawFile('foto1.jpg', 'f1');
      final raw2 = makeRawFile('foto2.jpg', 'f2');
      await notifier.addNote(
        petId: 'pet-1',
        title: 'Nota',
        content: 'Contenido',
        date: DateTime(2026, 1, 1),
        rawPhotoPaths: [raw1.path, raw2.path],
      );
      final original = (await container.read(notesProvider('pet-1').future)).single;
      final String keptPath = original.photoPaths[0];
      final String removedPath = original.photoPaths[1];

      final draft = Note(
        id: original.id,
        petId: original.petId,
        title: original.title,
        content: original.content,
        date: original.date,
        photoPaths: [keptPath], // el usuario sacó la segunda foto en la pantalla
      );

      await notifier.updateNote(original, draft);

      expect(
        File(removedPath).existsSync(),
        isFalse,
        reason: 'la foto sacada por el usuario debe borrarse del disco',
      );
      expect(
        File(keptPath).existsSync(),
        isTrue,
        reason: 'la foto que sigue presente en ambas listas no debe borrarse',
      );

      final updated = (await container.read(notesProvider('pet-1').future)).single;
      expect(updated.photoPaths, [keptPath]);
    });

    test('NO borra nada si la lista de fotos no cambió', () async {
      final container = buildContainer([]);
      final notifier = container.read(notesProvider('pet-1').notifier);

      final raw = makeRawFile('foto.jpg', 'data');
      await notifier.addNote(
        petId: 'pet-1',
        title: 'Nota',
        content: 'Contenido',
        date: DateTime(2026, 1, 1),
        rawPhotoPaths: [raw.path],
      );
      final original = (await container.read(notesProvider('pet-1').future)).single;

      final draft = Note(
        id: original.id,
        petId: original.petId,
        title: 'Nota (título editado)',
        content: original.content,
        date: original.date,
        photoPaths: original.photoPaths, // el usuario no tocó las fotos
      );

      await notifier.updateNote(original, draft);

      expect(
        File(original.photoPaths.single).existsSync(),
        isTrue,
        reason: 'no debe borrar una foto que el registro sigue usando',
      );
    });

    test(
      'si la escritura falla, las fotos viejas NO se borran (evita romper una referencia real)',
      () async {
        final rawOld = makeRawFile('old.jpg', 'old');
        final original = Note(
          petId: 'pet-1',
          title: 'Nota',
          content: 'Contenido',
          date: DateTime(2026, 1, 1),
          photoPaths: [rawOld.path],
        );
        final container = buildContainer([original], throwOnUpdate: true);
        final notifier = container.read(notesProvider('pet-1').notifier);

        final rawNew = makeRawFile('new.jpg', 'new');
        final draft = Note(
          id: original.id,
          petId: original.petId,
          title: original.title,
          content: original.content,
          date: original.date,
          photoPaths: [rawNew.path],
        );

        await expectLater(
          () => notifier.updateNote(original, draft),
          throwsException,
        );

        expect(
          File(rawOld.path).existsSync(),
          isTrue,
          reason: 'la fila vigente en la base sigue siendo la vieja; borrar su foto en este '
              'punto rompería una referencia real, no dejaría solo un huérfano',
        );
      },
    );
  });

  group('NotesNotifier.deleteNote', () {
    test('borra todas las fotos y el registro', () async {
      final container = buildContainer([]);
      final notifier = container.read(notesProvider('pet-1').notifier);

      final raw1 = makeRawFile('foto1.jpg', 'f1');
      final raw2 = makeRawFile('foto2.jpg', 'f2');
      await notifier.addNote(
        petId: 'pet-1',
        title: 'Nota',
        content: 'Contenido',
        date: DateTime(2026, 1, 1),
        rawPhotoPaths: [raw1.path, raw2.path],
      );
      final original = (await container.read(notesProvider('pet-1').future)).single;

      await notifier.deleteNote(original);

      for (final path in original.photoPaths) {
        expect(File(path).existsSync(), isFalse);
      }
      expect(await container.read(notesProvider('pet-1').future), isEmpty);
    });
  });

  group('NotesNotifier.deleteNotes - borrado múltiple', () {
    test('borra varias notas y sus fotos en una sola llamada', () async {
      final container = buildContainer([]);
      final notifier = container.read(notesProvider('pet-1').notifier);

      final raw1 = makeRawFile('foto1.jpg', 'f1');
      final raw2 = makeRawFile('foto2.jpg', 'f2');
      await notifier.addNote(
        petId: 'pet-1',
        title: 'Nota 1',
        content: 'Contenido',
        date: DateTime(2026, 1, 1),
        rawPhotoPaths: [raw1.path],
      );
      await notifier.addNote(
        petId: 'pet-1',
        title: 'Nota 2',
        content: 'Contenido',
        date: DateTime(2026, 1, 2),
        rawPhotoPaths: [raw2.path],
      );
      final notes = await container.read(notesProvider('pet-1').future);

      final failed = await notifier.deleteNotes(notes);

      expect(failed, isEmpty);
      for (final note in notes) {
        for (final path in note.photoPaths) {
          expect(File(path).existsSync(), isFalse);
        }
      }
      expect(await container.read(notesProvider('pet-1').future), isEmpty);
    });

    test(
      'fallo parcial: sigue con el resto del lote, no revierte lo ya borrado, y reporta lo que falló',
      () async {
        final rawA = makeRawFile('a.jpg', 'a');
        final rawB = makeRawFile('b.jpg', 'b');
        final rawC = makeRawFile('c.jpg', 'c');

        final noteA = Note(id: 'note-a', petId: 'pet-1', title: 'A', content: 'c', date: DateTime(2026, 1, 1), photoPaths: [rawA.path]);
        final noteB = Note(id: 'note-b', petId: 'pet-1', title: 'B', content: 'c', date: DateTime(2026, 1, 2), photoPaths: [rawB.path]);
        final noteC = Note(id: 'note-c', petId: 'pet-1', title: 'C', content: 'c', date: DateTime(2026, 1, 3), photoPaths: [rawC.path]);

        final container = buildContainer(
          [noteA, noteB, noteC],
          failDeleteIds: {'note-b'},
        );
        final notifier = container.read(notesProvider('pet-1').notifier);

        final failed = await notifier.deleteNotes([noteA, noteB, noteC]);

        expect(failed.map((n) => n.id), ['note-b']);

        final remaining = await container.read(notesProvider('pet-1').future);
        expect(remaining.map((n) => n.id), ['note-b']);

        expect(
          File(rawA.path).existsSync(),
          isFalse,
          reason: 'A se borró antes de la falla en B: no se revierte',
        );
        expect(
          File(rawC.path).existsSync(),
          isFalse,
          reason: 'el lote sigue después de la falla en B en vez de abortar el resto',
        );
        expect(
          File(rawB.path).existsSync(),
          isFalse,
          reason: 'orden heredado del delete individual (archivo antes que fila, igual que '
              'Document/Vaccination): si la fila falla DESPUÉS de borrar el archivo, la fila '
              'sobrevive apuntando a un archivo que ya no existe -riesgo preexistente al orden '
              'file-then-row, no introducido por el batch-',
        );
      },
    );
  });
}
