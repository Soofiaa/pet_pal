// Pruebas de PetsNotifier (petsProvider): mismo esqueleto que
// weight_record_providers_test.dart, con un fake en memoria que no toca
// sqflite. Es la base de la que depende dashboard_providers_test.dart.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/providers/pets_providers.dart';
import 'package:pet_pal/repositories/pet_repository.dart';

class _FakePetRepository implements PetRepository {
  _FakePetRepository(this.pets);

  final List<Pet> pets;

  @override
  Future<List<Pet>> getPets() async => List.of(pets);

  @override
  Future<void> insertPet(Pet pet) async => pets.add(pet);

  @override
  Future<void> updatePet(Pet pet) async {
    final index = pets.indexWhere((p) => p.id == pet.id);
    if (index != -1) pets[index] = pet;
  }

  @override
  Future<void> deletePet(String id) async {
    pets.removeWhere((p) => p.id == id);
  }
}

Pet _makePet(String id, String name) => Pet(
      id: id,
      name: name,
      species: 'Perro',
      breed: 'Mestizo',
      dob: DateTime(2020, 1, 1),
      color: 'Marrón',
    );

void main() {
  group('petsProvider (PetsNotifier)', () {
    test('carga la lista de mascotas desde el repository', () async {
      final fakePets = [_makePet('pet-1', 'Firulais'), _makePet('pet-2', 'Michi')];

      final container = ProviderContainer(
        overrides: [
          petRepositoryProvider.overrideWithValue(_FakePetRepository(fakePets)),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(petsProvider.future);

      expect(result.map((p) => p.id).toSet(), {'pet-1', 'pet-2'});
    });

    test('el estado pasa por loading y termina en data', () async {
      final fakePets = [_makePet('pet-1', 'Firulais')];

      final container = ProviderContainer(
        overrides: [
          petRepositoryProvider.overrideWithValue(_FakePetRepository(fakePets)),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(petsProvider), const AsyncValue<List<Pet>>.loading());

      await container.read(petsProvider.future);

      expect(container.read(petsProvider).value, hasLength(1));
    });

    test('refresh() vuelve a cargar después de un insert externo', () async {
      final fakePets = <Pet>[_makePet('pet-1', 'Firulais')];

      final container = ProviderContainer(
        overrides: [
          petRepositoryProvider.overrideWithValue(_FakePetRepository(fakePets)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(petsProvider.future);

      fakePets.add(_makePet('pet-2', 'Michi'));
      await container.read(petsProvider.notifier).refresh();

      expect(container.read(petsProvider).value, hasLength(2));
    });

    test('refresh() refleja un borrado externo', () async {
      final fakePets = <Pet>[_makePet('pet-1', 'Firulais'), _makePet('pet-2', 'Michi')];

      final container = ProviderContainer(
        overrides: [
          petRepositoryProvider.overrideWithValue(_FakePetRepository(fakePets)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(petsProvider.future);

      fakePets.removeWhere((p) => p.id == 'pet-1');
      await container.read(petsProvider.notifier).refresh();

      final result = container.read(petsProvider).value!;
      expect(result, hasLength(1));
      expect(result.first.id, 'pet-2');
    });

    test('deletePet quita la mascota del estado tras refrescar', () async {
      final fakePets = <Pet>[_makePet('pet-1', 'Firulais'), _makePet('pet-2', 'Michi')];

      final container = ProviderContainer(
        overrides: [
          petRepositoryProvider.overrideWithValue(_FakePetRepository(fakePets)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(petsProvider.future);

      await container.read(petsProvider.notifier).deletePet('pet-1');

      final result = container.read(petsProvider).value!;
      expect(result, hasLength(1));
      expect(result.first.id, 'pet-2');
    });
  });
}
