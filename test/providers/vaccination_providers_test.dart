// Pruebas de VaccinationsNotifier: la orquestación datos + recordatorio +
// archivos es código NUEVO (antes vivía inline en
// add_edit_vaccination_screen.dart / vaccinations_screen.dart), así que
// reminder_scheduler_test.dart no la cubre. Usa archivos TEMPORALES REALES
// en disco para las aserciones de limpieza de fotos -ImageStorageService es
// estático y opera directo sobre dart:io, sin ningún punto de inyección
// mockeable-, combinado con el repository fake (para los datos) y el canal
// mockeado de flutter_local_notifications (para observar las llamadas a
// ReminderScheduler), igual que en deworming_providers_test.dart.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pet_pal/models/vaccination.dart';
import 'package:pet_pal/providers/vaccination_providers.dart';
import 'package:pet_pal/repositories/vaccination_repository.dart';
import 'package:pet_pal/services/notification_service.dart';
import 'package:uuid/uuid.dart';

class _FakeVaccinationRepository implements VaccinationRepository {
  _FakeVaccinationRepository(this.records, {this.throwOnUpdate = false});

  final List<Vaccination> records;
  final bool throwOnUpdate;

  @override
  Future<List<Vaccination>> getVaccinationsForPet(String petId) async {
    return records.where((r) => r.petId == petId).toList();
  }

  @override
  Future<void> insertVaccination(Vaccination vaccination) async {
    records.add(vaccination);
  }

  @override
  Future<void> updateVaccination(Vaccination vaccination) async {
    if (throwOnUpdate) {
      throw Exception('fallo simulado al persistir la vacunación');
    }
    final index = records.indexWhere((r) => r.id == vaccination.id);
    if (index != -1) records[index] = vaccination;
  }

  @override
  Future<void> deleteVaccination(String id) async {
    records.removeWhere((r) => r.id == id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel =
      MethodChannel('dexterous.com/flutter/local_notifications');

  setUpAll(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
  });

  late List<MethodCall> calls;
  late Directory tempFilesDir;

  setUp(() async {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      switch (call.method) {
        case 'initialize':
        case 'requestNotificationsPermission':
        case 'requestExactAlarmsPermission':
        case 'canScheduleExactNotifications':
        case 'areNotificationsEnabled':
          return true;
        default:
          return null;
      }
    });
    tempFilesDir = await Directory.systemTemp.createTemp('vaccination_test_files_');
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    try {
      if (await tempFilesDir.exists()) {
        await tempFilesDir.delete(recursive: true);
      }
    } catch (_) {
      // Mejor esfuerzo: no crítico para el resultado de la prueba.
    }
  });

  File makeFile(String name, String content) {
    final file = File('${tempFilesDir.path}/$name');
    file.writeAsStringSync(content);
    return file;
  }

  ProviderContainer buildContainer(List<Vaccination> records, {bool throwOnUpdate = false}) {
    final container = ProviderContainer(
      overrides: [
        vaccinationRepositoryProvider.overrideWithValue(
          _FakeVaccinationRepository(records, throwOnUpdate: throwOnUpdate),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('VaccinationsNotifier - limpieza de archivos huérfanos', () {
    test('updateVaccination borra la foto de adhesivo reemplazada', () async {
      await NotificationService().init();

      final oldSticker = makeFile('old_sticker.jpg', 'old');
      final newSticker = makeFile('new_sticker.jpg', 'new');

      final original = Vaccination(
        petId: 'pet-1',
        vaccineName: 'Rabia',
        date: DateTime.now(),
        stickerPhotoPath: oldSticker.path,
      );
      final container = buildContainer([original]);

      final updated = original.copyWith(stickerPhotoPath: newSticker.path);
      await container
          .read(vaccinationsProvider('pet-1').notifier)
          .updateVaccination(original, updated);

      expect(oldSticker.existsSync(), isFalse,
          reason: 'la foto reemplazada debe limpiarse, no quedar huérfana');
      expect(newSticker.existsSync(), isTrue);
    });

    test(
      'updateVaccination NO borra la foto si la ruta no cambió',
      () async {
        await NotificationService().init();

        final sticker = makeFile('sticker.jpg', 'data');

        final original = Vaccination(
          petId: 'pet-1',
          vaccineName: 'Rabia',
          date: DateTime.now(),
          stickerPhotoPath: sticker.path,
        );
        final container = buildContainer([original]);

        // Solo cambia el nombre de la vacuna; la foto sigue siendo la misma.
        final updated = original.copyWith(vaccineName: 'Rabia (refuerzo)');
        await container
            .read(vaccinationsProvider('pet-1').notifier)
            .updateVaccination(original, updated);

        expect(
          sticker.existsSync(),
          isTrue,
          reason: 'no debe borrar un archivo que el registro sigue usando '
              '-el bug contrario sería peor que el huérfano que se está arreglando',
        );
      },
    );

    test(
      'updateVaccination diferencia stickerPhotoPath de extraPhotoPath',
      () async {
        await NotificationService().init();

        final sticker = makeFile('sticker.jpg', 'sticker'); // no cambia
        final oldExtra = makeFile('old_extra.jpg', 'old-extra');
        final newExtra = makeFile('new_extra.jpg', 'new-extra');

        final original = Vaccination(
          petId: 'pet-1',
          vaccineName: 'Rabia',
          date: DateTime.now(),
          stickerPhotoPath: sticker.path,
          extraPhotoPath: oldExtra.path,
        );
        final container = buildContainer([original]);

        final updated = original.copyWith(extraPhotoPath: newExtra.path);
        await container
            .read(vaccinationsProvider('pet-1').notifier)
            .updateVaccination(original, updated);

        expect(sticker.existsSync(), isTrue,
            reason: 'stickerPhotoPath no cambió, no debe tocarse');
        expect(oldExtra.existsSync(), isFalse,
            reason: 'extraPhotoPath sí cambió, la vieja debe limpiarse');
        expect(newExtra.existsSync(), isTrue);
      },
    );

    test('deleteVaccination borra ambos archivos', () async {
      await NotificationService().init();

      final sticker = makeFile('sticker.jpg', 's');
      final extra = makeFile('extra.jpg', 'e');

      final vaccination = Vaccination(
        petId: 'pet-1',
        vaccineName: 'Rabia',
        date: DateTime.now(),
        stickerPhotoPath: sticker.path,
        extraPhotoPath: extra.path,
      );
      final container = buildContainer([vaccination]);

      await container
          .read(vaccinationsProvider('pet-1').notifier)
          .deleteVaccination(vaccination);

      expect(sticker.existsSync(), isFalse);
      expect(extra.existsSync(), isFalse);
    });

    test(
      'si la escritura falla, la foto vieja NO se borra (evita romper una referencia real)',
      () async {
        await NotificationService().init();

        final oldSticker = makeFile('old.jpg', 'old');
        final newSticker = makeFile('new.jpg', 'new');

        final original = Vaccination(
          petId: 'pet-1',
          vaccineName: 'Rabia',
          date: DateTime.now(),
          stickerPhotoPath: oldSticker.path,
        );
        final container = buildContainer([original], throwOnUpdate: true);

        final updated = original.copyWith(stickerPhotoPath: newSticker.path);

        await expectLater(
          () => container
              .read(vaccinationsProvider('pet-1').notifier)
              .updateVaccination(original, updated),
          throwsException,
        );

        expect(
          oldSticker.existsSync(),
          isTrue,
          reason: 'la fila vigente en la base sigue siendo la vieja '
              '(con la ruta vieja); borrarla en este punto rompería una '
              'referencia real, no dejaría solo un huérfano',
        );
      },
    );
  });

  group('VaccinationsNotifier - IDs sin colisión', () {
    test('addVaccination agenda con id distinto para cada registro', () async {
      await NotificationService().init();
      final records = <Vaccination>[];
      final container = buildContainer(records);
      calls.clear();

      final v1 = Vaccination(
        id: const Uuid().v4(),
        petId: 'pet-1',
        vaccineName: 'Rabia',
        date: DateTime.now(),
        nextDueDate: DateTime.now().add(const Duration(days: 30)),
      );
      final v2 = Vaccination(
        id: const Uuid().v4(),
        petId: 'pet-1',
        vaccineName: 'Parvovirus',
        date: DateTime.now(),
        nextDueDate: DateTime.now().add(const Duration(days: 45)),
      );

      await container.read(vaccinationsProvider('pet-1').notifier).addVaccination(v1);
      await container.read(vaccinationsProvider('pet-1').notifier).addVaccination(v2);

      final scheduleCalls =
          calls.where((c) => c.method == 'zonedSchedule').toList();
      expect(scheduleCalls, hasLength(2));

      final ids = scheduleCalls.map((c) => c.arguments['id'] as int).toList();
      expect(ids.toSet().length, ids.length,
          reason: 'ids repetidos entre dos vacunaciones distintas');
    });

    test(
      'updateVaccination cancela el id anterior antes de reprogramar el mismo id',
      () async {
        await NotificationService().init();
        final original = Vaccination(
          id: const Uuid().v4(),
          petId: 'pet-1',
          vaccineName: 'Rabia',
          date: DateTime.now(),
          nextDueDate: DateTime.now().add(const Duration(days: 30)),
        );
        final container = buildContainer([original]);
        calls.clear();

        final updated = original.copyWith(
          nextDueDate: DateTime.now().add(const Duration(days: 60)),
        );
        await container
            .read(vaccinationsProvider('pet-1').notifier)
            .updateVaccination(original, updated);

        final relevantCalls = calls
            .where((c) => c.method == 'cancel' || c.method == 'zonedSchedule')
            .toList();
        expect(relevantCalls, hasLength(2));
        expect(relevantCalls[0].method, 'cancel');
        expect(relevantCalls[1].method, 'zonedSchedule');

        final cancelId = relevantCalls[0].arguments['id'] as int;
        final scheduleId = relevantCalls[1].arguments['id'] as int;
        expect(cancelId, scheduleId);
      },
    );
  });
}
