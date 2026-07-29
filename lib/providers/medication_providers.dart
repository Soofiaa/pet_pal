import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/medication.dart';
import 'package:pet_pal/providers/database_providers.dart';
import 'package:pet_pal/repositories/medication_repository.dart';
import 'package:pet_pal/services/reminder_scheduler.dart';

final medicationRepositoryProvider = Provider<MedicationRepository>((ref) {
  return MedicationRepository(ref.watch(databaseHelperProvider));
});

/// Reemplaza los antiguos campos _medications manejados a mano en
/// medications_screen.dart. Es la única puerta de escritura real para
/// Medicación (ver el comentario de MedicationRepository). No decide
/// cuál de las tres ramas de ReminderScheduler aplica -legado sin
/// reminderTimes, hash horario×día con endDate, o repetible sin
/// endDate-: eso ya lo encapsula scheduleMedicationReminders/
/// cancelMedicationReminders, así que el notifier solo necesita
/// llamarlos en el orden correcto.
final medicationsProvider = AsyncNotifierProvider.family<MedicationsNotifier,
    List<Medication>, String>(MedicationsNotifier.new);

class MedicationsNotifier
    extends FamilyAsyncNotifier<List<Medication>, String> {
  @override
  Future<List<Medication>> build(String petId) async {
    final repository = ref.watch(medicationRepositoryProvider);
    return repository.getMedicationsForPet(petId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build(arg));
  }

  /// Agrega una nueva medicación. Mismo orden que usaba
  /// add_edit_medications_screen.dart: programa el/los recordatorio(s) y
  /// recién después persiste el registro.
  Future<void> addMedication(Medication medication) async {
    await ReminderScheduler.scheduleMedicationReminders(medication);
    await ref.read(medicationRepositoryProvider).insertMedication(medication);
    await refresh();
  }

  /// Actualiza una medicación existente. Mismo orden que usaba
  /// add_edit_medications_screen.dart: cancela los recordatorios
  /// anteriores con el objeto viejo (el rango de días u horarios pudo
  /// haber cambiado), programa los nuevos, y recién después persiste el
  /// cambio.
  Future<void> updateMedication(
    Medication oldMedication,
    Medication updatedMedication,
  ) async {
    await ReminderScheduler.cancelMedicationReminders(oldMedication);
    await ReminderScheduler.scheduleMedicationReminders(updatedMedication);
    await ref
        .read(medicationRepositoryProvider)
        .updateMedication(updatedMedication);
    await refresh();
  }

  /// Elimina una medicación y cancela sus recordatorios. Mismo orden que
  /// usaba medications_screen.dart: cancela antes de borrar.
  Future<void> deleteMedication(Medication medication) async {
    await ReminderScheduler.cancelMedicationReminders(medication);
    await ref
        .read(medicationRepositoryProvider)
        .deleteMedication(medication.id!);
    await refresh();
  }
}
