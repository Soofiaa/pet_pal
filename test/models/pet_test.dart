// Regresión: DataBackupService.exportAllData armaba el JSON de cada
// mascota a mano en vez de usar Pet.toJson(), y se olvidó de
// microchipNumber cuando ese campo se agregó al modelo -el backup lo
// perdía en silencio-. Ahora exportAllData usa pet.toJson() directo, así
// que alcanza con confirmar que el propio round-trip toJson/fromJson de
// Pet preserva todos los campos, incluido microchipNumber.
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_pal/models/pet.dart';

void main() {
  group('Pet.toJson / Pet.fromJson', () {
    test('conserva microchipNumber en el round-trip', () {
      final pet = Pet(
        id: 'pet-1',
        name: 'Firulais',
        species: 'Perro',
        breed: 'Mestizo',
        dob: DateTime(2020, 1, 1),
        color: 'Marrón',
        microchipNumber: '978000123456789',
      );

      final roundTripped = Pet.fromJson(pet.toJson());

      expect(roundTripped.microchipNumber, '978000123456789');
    });

    test('conserva microchipNumber null (mascota sin microchip registrado)', () {
      final pet = Pet(
        id: 'pet-1',
        name: 'Firulais',
        species: 'Perro',
        breed: 'Mestizo',
        dob: DateTime(2020, 1, 1),
        color: 'Marrón',
      );

      final roundTripped = Pet.fromJson(pet.toJson());

      expect(roundTripped.microchipNumber, isNull);
    });

    test('conserva el resto de los campos en el round-trip', () {
      final pet = Pet(
        id: 'pet-1',
        name: 'Firulais',
        species: 'Perro',
        breed: 'Mestizo',
        dob: DateTime(2020, 1, 1),
        color: 'Marrón',
        imageUrl: '/tmp/foto.jpg',
      );

      final roundTripped = Pet.fromJson(pet.toJson());

      expect(roundTripped.name, pet.name);
      expect(roundTripped.species, pet.species);
      expect(roundTripped.breed, pet.breed);
      expect(roundTripped.dob, pet.dob);
      expect(roundTripped.color, pet.color);
      expect(roundTripped.imageUrl, pet.imageUrl);
    });
  });
}
