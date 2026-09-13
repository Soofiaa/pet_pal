import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/vital_sign_record.dart';
import 'package:pet_pal/providers/database_providers.dart';
import 'package:pet_pal/repositories/vital_sign_repository.dart';

final vitalSignRepositoryProvider = Provider<VitalSignRepository>((ref) {
  return VitalSignRepository(ref.watch(databaseHelperProvider));
});

/// Única puerta de escritura real para Signos Vitales (ver comentario de
/// VitalSignRepository). Family por mascota, igual que weightRecordsProvider;
/// devuelve todos los tipos de signo vital de la mascota, sin filtrar -las
/// pantallas filtran por VitalSignType localmente, igual que hace el
/// dashboard con los tipos de evento accionables.
final vitalSignRecordsProvider = AsyncNotifierProvider.family<
    VitalSignRecordsNotifier, List<VitalSignRecord>, String>(
  VitalSignRecordsNotifier.new,
);

class VitalSignRecordsNotifier
    extends FamilyAsyncNotifier<List<VitalSignRecord>, String> {
  @override
  Future<List<VitalSignRecord>> build(String petId) async {
    final repository = ref.watch(vitalSignRepositoryProvider);
    final records = await repository.getVitalSignRecordsForPet(petId);
    records.sort((a, b) => a.date.compareTo(b.date));
    return records;
  }

  /// Vuelve a cargar los registros de esta mascota.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build(arg));
  }

  /// Agrega un registro. El valor fuera de rango se señaliza solo en la UI
  /// (fondo rojo + ícono de advertencia en vital_sign_screen.dart), sin
  /// notificación push: el usuario lo carga a mano, así que ya sabe en el
  /// momento que el valor es anormal.
  Future<void> addVitalSignRecord(VitalSignRecord record) async {
    final repository = ref.read(vitalSignRepositoryProvider);
    await repository.insertVitalSignRecord(record);
    await refresh();
  }

  /// Actualiza un registro existente. A diferencia de addVitalSignRecord,
  /// no vuelve a evaluar la alerta de rango anormal: es la misma decisión
  /// de diseño que weightRecordsProvider, que tampoco reacciona a ediciones
  /// -corregir un dato ya cargado no debería reabrir una alerta puntual.
  Future<void> updateVitalSignRecord(VitalSignRecord record) async {
    await ref.read(vitalSignRepositoryProvider).updateVitalSignRecord(record);
    await refresh();
  }

  Future<void> deleteVitalSignRecord(int id) async {
    await ref.read(vitalSignRepositoryProvider).deleteVitalSignRecord(id);
    await refresh();
  }
}
