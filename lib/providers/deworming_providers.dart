import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/deworming.dart';
import 'package:pet_pal/models/deworming_product.dart';
import 'package:pet_pal/providers/database_providers.dart';
import 'package:pet_pal/repositories/deworming_repository.dart';
import 'package:pet_pal/repositories/deworming_product_repository.dart';
import 'package:pet_pal/services/reminder_scheduler.dart';

final dewormingRepositoryProvider = Provider<DewormingRepository>((ref) {
  return DewormingRepository(ref.watch(databaseHelperProvider));
});

final dewormingProductRepositoryProvider = Provider<DewormingProductRepository>((ref) {
  return DewormingProductRepository(ref.watch(databaseHelperProvider));
});

final dewormingProductsProvider = AsyncNotifierProvider<DewormingProductsNotifier, List<DewormingProduct>>(
  DewormingProductsNotifier.new,
);

class DewormingProductsNotifier extends AsyncNotifier<List<DewormingProduct>> {
  @override
  Future<List<DewormingProduct>> build() async {
    return ref.watch(dewormingProductRepositoryProvider).getProducts();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> addProduct(DewormingProduct product) async {
    await ref.read(dewormingProductRepositoryProvider).insertProduct(product);
    await refresh();
  }

  Future<void> updateProduct(DewormingProduct product) async {
    await ref.read(dewormingProductRepositoryProvider).updateProduct(product);
    await refresh();
  }

  Future<void> deleteProduct(String id) async {
    await ref.read(dewormingProductRepositoryProvider).deleteProduct(id);
    await refresh();
  }
}

/// Reemplaza los antiguos campos _dewormings manejados a mano en
/// deworming_screen.dart. A diferencia de weightRecordsProvider, este
/// notifier también orquesta ReminderScheduler: es la única puerta de
/// escritura real para Desparasitación (ver el comentario de
/// DewormingRepository).
final dewormingsProvider = AsyncNotifierProvider.family<DewormingsNotifier,
    List<Deworming>, String>(DewormingsNotifier.new);

class DewormingsNotifier extends FamilyAsyncNotifier<List<Deworming>, String> {
  @override
  Future<List<Deworming>> build(String petId) async {
    final repository = ref.watch(dewormingRepositoryProvider);
    return repository.getDewormingsForPet(petId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build(arg));
  }

  /// Agrega una nueva desparasitación. Mismo orden que usaba
  /// add_edit_deworming_screen.dart antes de esta migración: programa el
  /// recordatorio y recién después persiste el registro.
  Future<void> addDeworming(Deworming deworming) async {
    await ReminderScheduler.scheduleDewormingReminder(deworming);
    await ref.read(dewormingRepositoryProvider).insertDeworming(deworming);
    await refresh();
  }

  /// Actualiza una desparasitación existente. Mismo orden que usaba
  /// add_edit_deworming_screen.dart: cancela el recordatorio anterior con
  /// el objeto viejo (antes de que se sobreescriba), programa el nuevo, y
  /// recién después persiste el cambio.
  Future<void> updateDeworming(
    Deworming oldDeworming,
    Deworming updatedDeworming,
  ) async {
    await ReminderScheduler.cancelDewormingReminder(oldDeworming);
    await ReminderScheduler.scheduleDewormingReminder(updatedDeworming);
    await ref.read(dewormingRepositoryProvider).updateDeworming(updatedDeworming);
    await refresh();
  }

  /// Elimina una desparasitación y cancela su recordatorio. Mismo orden
  /// que usaba deworming_screen.dart: cancela antes de borrar.
  Future<void> deleteDeworming(Deworming deworming) async {
    await ReminderScheduler.cancelDewormingReminder(deworming);
    await ref.read(dewormingRepositoryProvider).deleteDeworming(deworming.id!);
    await refresh();
  }
}
