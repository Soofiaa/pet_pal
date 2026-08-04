import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/vaccination.dart';
import 'package:pet_pal/models/vaccination_product.dart';
import 'package:pet_pal/providers/database_providers.dart';
import 'package:pet_pal/repositories/vaccination_repository.dart';
import 'package:pet_pal/repositories/vaccination_product_repository.dart';
import 'package:pet_pal/services/image_storage_service.dart';
import 'package:pet_pal/services/reminder_scheduler.dart';

final vaccinationRepositoryProvider = Provider<VaccinationRepository>((ref) {
  return VaccinationRepository(ref.watch(databaseHelperProvider));
});

final vaccinationProductRepositoryProvider = Provider<VaccinationProductRepository>((ref) {
  return VaccinationProductRepository(ref.watch(databaseHelperProvider));
});

final vaccinationProductsProvider = AsyncNotifierProvider<VaccinationProductsNotifier, List<VaccinationProduct>>(
  VaccinationProductsNotifier.new,
);

class VaccinationProductsNotifier extends AsyncNotifier<List<VaccinationProduct>> {
  @override
  Future<List<VaccinationProduct>> build() async {
    return ref.watch(vaccinationProductRepositoryProvider).getProducts();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> addProduct(VaccinationProduct product) async {
    await ref.read(vaccinationProductRepositoryProvider).insertProduct(product);
    await refresh();
  }

  Future<void> updateProduct(VaccinationProduct product) async {
    await ref.read(vaccinationProductRepositoryProvider).updateProduct(product);
    await refresh();
  }

  Future<void> deleteProduct(String id) async {
    await ref.read(vaccinationProductRepositoryProvider).deleteProduct(id);
    await refresh();
  }
}

/// Reemplaza los antiguos campos _vaccinations/_isLoading manejados a mano
/// en vaccinations_screen.dart. Igual que DewormingsNotifier, es la única
/// puerta de escritura real para Vacunas (ver el comentario de
/// VaccinationRepository) — acá además de ReminderScheduler se orquesta
/// ImageStorageService, ya que las fotos de una vacunación son parte de
/// la misma operación de guardar/eliminar.
final vaccinationsProvider = AsyncNotifierProvider.family<VaccinationsNotifier,
    List<Vaccination>, String>(VaccinationsNotifier.new);

class VaccinationsNotifier
    extends FamilyAsyncNotifier<List<Vaccination>, String> {
  @override
  Future<List<Vaccination>> build(String petId) async {
    final repository = ref.watch(vaccinationRepositoryProvider);
    final vaccinations = await repository.getVaccinationsForPet(petId);
    vaccinations.sort((a, b) => b.date.compareTo(a.date));
    return vaccinations;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build(arg));
  }

  /// Agrega una nueva vacunación. Mismo orden que usaba
  /// add_edit_vaccination_screen.dart: programa el recordatorio y recién
  /// después persiste el registro. Las fotos ya llegan guardadas en rutas
  /// permanentes -eso lo resuelve la pantalla con ImageStorageService
  /// antes de llamar acá, ya que picking/cropping son inherentemente UI-,
  /// así que no hay nada que limpiar en un alta.
  Future<void> addVaccination(Vaccination vaccination) async {
    await ReminderScheduler.scheduleVaccinationReminder(vaccination);
    await ref.read(vaccinationRepositoryProvider).insertVaccination(vaccination);
    await refresh();
  }

  /// Actualiza una vacunación existente: cancela el recordatorio anterior
  /// y programa el nuevo (mismo orden que usaba la pantalla), persiste el
  /// cambio, y RECIÉN DESPUÉS borra cualquier foto que haya quedado
  /// reemplazada.
  ///
  /// Antes de esta migración, add_edit_vaccination_screen.dart nunca
  /// borraba la foto vieja al reemplazarla en una edición -quedaba
  /// huérfana en petpal_files/vaccinations/ para siempre-. Se corrige acá
  /// porque este es el único lugar que tiene tanto el objeto viejo como
  /// el nuevo a mano, lo mismo que ya hacía falta para cancelar/reprogramar
  /// el recordatorio correctamente.
  ///
  /// El borrado de archivos va DESPUÉS de persistir el cambio a propósito:
  /// si updateVaccination fallara, la fila vigente en la base sigue siendo
  /// la vieja (con las rutas viejas), así que borrar el archivo viejo en
  /// ese caso rompería una referencia real. Si algo falla recién después
  /// de guardar pero antes de limpiar, el resultado es un archivo
  /// huérfano -no una referencia rota-, que es el mismo tipo de residuo
  /// que ya maneja OrphanCleanupService.
  Future<void> updateVaccination(
    Vaccination oldVaccination,
    Vaccination updatedVaccination,
  ) async {
    await ReminderScheduler.cancelVaccinationReminder(oldVaccination);
    await ReminderScheduler.scheduleVaccinationReminder(updatedVaccination);
    await ref
        .read(vaccinationRepositoryProvider)
        .updateVaccination(updatedVaccination);

    if (oldVaccination.stickerPhotoPath != updatedVaccination.stickerPhotoPath) {
      await ImageStorageService.deleteFileIfExist(oldVaccination.stickerPhotoPath);
    }
    if (oldVaccination.extraPhotoPath != updatedVaccination.extraPhotoPath) {
      await ImageStorageService.deleteFileIfExist(oldVaccination.extraPhotoPath);
    }

    await refresh();
  }

  /// Elimina una vacunación y cancela su recordatorio. Mismo orden que
  /// usaba vaccinations_screen.dart: archivos primero, recordatorio
  /// después, fila al final.
  Future<void> deleteVaccination(Vaccination vaccination) async {
    await ImageStorageService.deleteFilesIfExist([
      vaccination.stickerPhotoPath,
      vaccination.extraPhotoPath,
    ]);
    await ReminderScheduler.cancelVaccinationReminder(vaccination);
    await ref.read(vaccinationRepositoryProvider).deleteVaccination(vaccination.id);
    await refresh();
  }
}
