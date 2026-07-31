// Pruebas de VitalSignRecordsNotifier (vitalSignRecordsProvider): mismo
// esqueleto que weight_record_providers_test.dart (fake repository en
// memoria), más el mock de canal de plataforma de
// notification_service_test.dart para verificar que un valor fuera de
// rango efectivamente dispara showImmediateNotification (y uno normal no).
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pet_pal/models/vital_sign_config.dart';
import 'package:pet_pal/models/vital_sign_record.dart';
import 'package:pet_pal/providers/vital_sign_providers.dart';
import 'package:pet_pal/repositories/vital_sign_repository.dart';
import 'package:pet_pal/services/notification_service.dart';

class _FakeVitalSignRepository implements VitalSignRepository {
  _FakeVitalSignRepository(this.records);

  final List<VitalSignRecord> records;
  int _nextId = 1;

  @override
  Future<List<VitalSignRecord>> getVitalSignRecordsForPet(
    String petId, {
    VitalSignType? type,
  }) async {
    return records
        .where((r) => r.petId == petId && (type == null || r.type == type))
        .toList();
  }

  @override
  Future<int> insertVitalSignRecord(VitalSignRecord record) async {
    final id = _nextId++;
    records.add(record.copyWith(id: id));
    return id;
  }

  @override
  Future<void> updateVitalSignRecord(VitalSignRecord record) async {
    final index = records.indexWhere((r) => r.id == record.id);
    if (index != -1) records[index] = record;
  }

  @override
  Future<void> deleteVitalSignRecord(int id) async {
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

  late List<MethodCall> notificationCalls;

  setUp(() async {
    notificationCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      notificationCalls.add(call);
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
    await NotificationService().init();
    notificationCalls.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('vitalSignRecordsProvider (VitalSignRecordsNotifier)', () {
    test('carga y ordena los registros por fecha ascendente', () async {
      final fakeRecords = [
        VitalSignRecord(id: 1, petId: 'pet-1', type: VitalSignType.temperature, value: 38.5, date: DateTime(2026, 3, 1)),
        VitalSignRecord(id: 2, petId: 'pet-1', type: VitalSignType.temperature, value: 38.7, date: DateTime(2026, 1, 1)),
      ];

      final container = ProviderContainer(
        overrides: [
          vitalSignRepositoryProvider.overrideWithValue(
            _FakeVitalSignRepository(fakeRecords),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(vitalSignRecordsProvider('pet-1').future);

      expect(result.map((r) => r.id).toList(), [2, 1]);
    });

    test('addVitalSignRecord con valor dentro de rango no dispara alerta', () async {
      final fakeRecords = <VitalSignRecord>[];

      final container = ProviderContainer(
        overrides: [
          vitalSignRepositoryProvider.overrideWithValue(
            _FakeVitalSignRepository(fakeRecords),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(vitalSignRecordsProvider('pet-1').future);
      await container.read(vitalSignRecordsProvider('pet-1').notifier).addVitalSignRecord(
            VitalSignRecord(petId: 'pet-1', type: VitalSignType.temperature, value: 38.5, date: DateTime(2026, 1, 1)),
          );

      expect(notificationCalls.where((c) => c.method == 'show'), isEmpty);
      expect(container.read(vitalSignRecordsProvider('pet-1')).value, hasLength(1));
    });

    test('addVitalSignRecord con valor fuera de rango dispara showImmediateNotification', () async {
      final fakeRecords = <VitalSignRecord>[];

      final container = ProviderContainer(
        overrides: [
          vitalSignRepositoryProvider.overrideWithValue(
            _FakeVitalSignRepository(fakeRecords),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(vitalSignRecordsProvider('pet-1').future);
      // 41.0°C está por encima del normalMax (39.2) configurado para
      // VitalSignType.temperature.
      await container.read(vitalSignRecordsProvider('pet-1').notifier).addVitalSignRecord(
            VitalSignRecord(petId: 'pet-1', type: VitalSignType.temperature, value: 41.0, date: DateTime(2026, 1, 1)),
          );

      final showCalls = notificationCalls.where((c) => c.method == 'show').toList();
      expect(showCalls, hasLength(1));
      expect(showCalls.first.arguments['title'], contains('Temperatura'));
    });

    test('deleteVitalSignRecord elimina y refresca', () async {
      final fakeRecords = <VitalSignRecord>[
        VitalSignRecord(id: 1, petId: 'pet-1', type: VitalSignType.temperature, value: 38.5, date: DateTime(2026, 1, 1)),
      ];

      final container = ProviderContainer(
        overrides: [
          vitalSignRepositoryProvider.overrideWithValue(
            _FakeVitalSignRepository(fakeRecords),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(vitalSignRecordsProvider('pet-1').future);
      await container.read(vitalSignRecordsProvider('pet-1').notifier).deleteVitalSignRecord(1);

      expect(container.read(vitalSignRecordsProvider('pet-1')).value, isEmpty);
    });
  });
}
