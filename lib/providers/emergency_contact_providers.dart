import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/emergency_contact.dart';
import 'package:pet_pal/providers/database_providers.dart';

final emergencyContactsProvider = AsyncNotifierProvider<EmergencyContactsNotifier, List<EmergencyContact>>(
  EmergencyContactsNotifier.new,
);

class EmergencyContactsNotifier extends AsyncNotifier<List<EmergencyContact>> {
  @override
  Future<List<EmergencyContact>> build() async {
    final dbHelper = ref.watch(databaseHelperProvider);
    return dbHelper.getEmergencyContacts();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> addContact(EmergencyContact contact) async {
    final dbHelper = ref.read(databaseHelperProvider);
    await dbHelper.insertEmergencyContact(contact);
    await refresh();
  }

  Future<void> updateContact(EmergencyContact contact) async {
    final dbHelper = ref.read(databaseHelperProvider);
    await dbHelper.updateEmergencyContact(contact);
    await refresh();
  }

  Future<void> deleteContact(String id) async {
    final dbHelper = ref.read(databaseHelperProvider);
    await dbHelper.deleteEmergencyContact(id);
    await refresh();
  }
}
