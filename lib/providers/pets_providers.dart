import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/providers/database_providers.dart';
import 'package:pet_pal/repositories/pet_repository.dart';

final petRepositoryProvider = Provider<PetRepository>((ref) {
  return PetRepository(ref.watch(databaseHelperProvider));
});

/// Reemplaza los antiguos campos _pets/_isLoading manejados a mano con
/// setState en home_screen.dart. No es family: es la lista global de
/// mascotas del usuario, base para el dashboard "Hoy" (dashboard_providers.dart).
final petsProvider = AsyncNotifierProvider<PetsNotifier, List<Pet>>(
  PetsNotifier.new,
);

class PetsNotifier extends AsyncNotifier<List<Pet>> {
  @override
  Future<List<Pet>> build() async {
    final repository = ref.watch(petRepositoryProvider);
    return repository.getPets();
  }

  /// Vuelve a cargar la lista de mascotas. Se llama después de agregar,
  /// editar o eliminar una mascota.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  /// Elimina una mascota. Pasa siempre por PetRepository.deletePet (nunca
  /// DatabaseHelper directo) para que se cancelen sus recordatorios
  /// pendientes antes de borrar el registro — ver el comentario de
  /// PetRepository.deletePet.
  Future<void> deletePet(String id) async {
    await ref.read(petRepositoryProvider).deletePet(id);
    await refresh();
  }
}
