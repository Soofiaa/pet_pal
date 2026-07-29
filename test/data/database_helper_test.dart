// Pruebas de DatabaseHelper: borrado en cascada e integridad referencial.
//
// sqflite habla con código nativo de Android/iOS por canales de plataforma,
// que no existen dentro de `flutter test`. sqflite_common_ffi (del mismo
// autor de sqflite) sustituye esa implementación por una real basada en FFI,
// así estas pruebas ejercitan SQLite de verdad -incluyendo
// `PRAGMA foreign_keys = ON`- sin necesitar un emulador ni un dispositivo.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/appointment.dart';
import 'package:pet_pal/models/deworming.dart';
import 'package:pet_pal/models/document.dart';
import 'package:pet_pal/models/food_allergy.dart';
import 'package:pet_pal/models/medication.dart';
import 'package:pet_pal/models/note.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/vaccination.dart';
import 'package:pet_pal/models/weight_record.dart';

Future<Pet> _insertSamplePetWithOneRowPerChildTable(DatabaseHelper dbHelper) async {
  final pet = Pet(
    name: 'Firulais',
    species: 'Perro',
    breed: 'Mestizo',
    dob: DateTime(2020, 1, 1),
    color: 'Marrón',
  );
  await dbHelper.insertPet(pet);

  await dbHelper.insertNote(Note(
    petId: pet.id,
    title: 'Nota',
    content: 'Contenido de la nota',
    date: DateTime.now(),
  ));

  await dbHelper.insertVaccination(Vaccination(
    petId: pet.id,
    vaccineName: 'Rabia',
    date: DateTime.now(),
  ));

  await dbHelper.insertAppointment(Appointment(
    petId: pet.id,
    dateTime: DateTime.now().add(const Duration(days: 1)),
    title: 'Control anual',
  ));

  await dbHelper.insertWeightRecord(WeightRecord(
    petId: pet.id,
    weight: 12.3,
    date: DateTime.now(),
  ));

  await dbHelper.insertFoodAllergy(FoodAllergy(
    petId: pet.id,
    food: 'Pollo',
    dateRecorded: DateTime.now(),
  ));

  await dbHelper.insertDeworming(Deworming(
    petId: pet.id,
    product: 'ProductoX',
    date: DateTime.now(),
  ));

  await dbHelper.insertMedication(Medication(
    petId: pet.id,
    name: 'MedicamentoX',
    dosage: '1 pastilla',
    frequency: 'Cada 12 horas',
    notes: '',
    startDate: DateTime.now(),
  ));

  await dbHelper.insertDocument(Document(
    petId: pet.id,
    categoria: 'Receta',
    titulo: 'Receta de control',
    fecha: DateTime.now(),
    filePath: '/tmp/documento_falso.pdf',
  ));

  return pet;
}

Future<void> _expectChildRowCountsForPet(
  DatabaseHelper dbHelper,
  String petId,
  int expectedCount,
) async {
  expect((await dbHelper.getNotesForPet(petId)).length, expectedCount);
  expect((await dbHelper.getVaccinationsForPet(petId)).length, expectedCount);
  expect((await dbHelper.getAppointmentsForPet(petId)).length, expectedCount);
  expect((await dbHelper.getWeightRecordsForPet(petId)).length, expectedCount);
  expect((await dbHelper.getFoodAllergiesForPet(petId)).length, expectedCount);
  expect((await dbHelper.getDewormingsForPet(petId)).length, expectedCount);
  expect((await dbHelper.getMedicationsForPet(petId)).length, expectedCount);
  expect((await dbHelper.getDocumentsForPet(petId)).length, expectedCount);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // DatabaseHelper es un singleton: la conexión real se abre una única vez
  // por proceso y se reutiliza entre pruebas. Para que cada prueba parta de
  // un estado limpio sin tocar el código de producción, se vacían todas las
  // tablas antes de cada una (deleteAllData ya existe para el flujo de
  // restauración de backups).
  setUp(() async {
    await DatabaseHelper().deleteAllData();
  });

  group('DatabaseHelper - borrado en cascada', () {
    test('eliminar una mascota borra en cascada las 8 tablas hijas', () async {
      final dbHelper = DatabaseHelper();
      final pet = await _insertSamplePetWithOneRowPerChildTable(dbHelper);

      // Confirma que efectivamente se insertó una fila en cada tabla antes
      // de borrar, para que la prueba no pase "por accidente" si algún
      // insert fallara silenciosamente.
      await _expectChildRowCountsForPet(dbHelper, pet.id, 1);

      await dbHelper.deletePet(pet.id);

      expect(await dbHelper.getPetById(pet.id), isNull);
      await _expectChildRowCountsForPet(dbHelper, pet.id, 0);
    });

    test('eliminar una mascota no afecta las filas de otra mascota', () async {
      final dbHelper = DatabaseHelper();

      final petA = await _insertSamplePetWithOneRowPerChildTable(dbHelper);
      final petB = await _insertSamplePetWithOneRowPerChildTable(dbHelper);

      await dbHelper.deletePet(petA.id);

      await _expectChildRowCountsForPet(dbHelper, petA.id, 0);
      await _expectChildRowCountsForPet(dbHelper, petB.id, 1);
      expect(await dbHelper.getPetById(petB.id), isNotNull);
    });
  });

  group('DatabaseHelper - integridad referencial', () {
    test('insertar una nota con petId inexistente falla', () async {
      final dbHelper = DatabaseHelper();

      expect(
        () => dbHelper.insertNote(Note(
          petId: 'pet-que-no-existe',
          title: 'Nota huérfana',
          content: 'x',
          date: DateTime.now(),
        )),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('insertar una vacuna con petId inexistente falla', () async {
      final dbHelper = DatabaseHelper();

      expect(
        () => dbHelper.insertVaccination(Vaccination(
          petId: 'pet-que-no-existe',
          vaccineName: 'Rabia',
          date: DateTime.now(),
        )),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('insertar un documento con petId inexistente falla', () async {
      final dbHelper = DatabaseHelper();

      expect(
        () => dbHelper.insertDocument(Document(
          petId: 'pet-que-no-existe',
          categoria: 'Otro',
          titulo: 'Doc huérfano',
          fecha: DateTime.now(),
          filePath: '/tmp/x.pdf',
        )),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('insertar una alergia alimentaria con petId inexistente falla', () async {
      final dbHelper = DatabaseHelper();

      expect(
        () => dbHelper.insertFoodAllergy(FoodAllergy(
          petId: 'pet-que-no-existe',
          food: 'Pollo',
          dateRecorded: DateTime.now(),
        )),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('insertar una cita con petId inexistente falla', () async {
      final dbHelper = DatabaseHelper();

      expect(
        () => dbHelper.insertAppointment(Appointment(
          petId: 'pet-que-no-existe',
          dateTime: DateTime.now().add(const Duration(days: 1)),
          title: 'Control huérfano',
        )),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('insertar un registro de peso con petId inexistente falla', () async {
      final dbHelper = DatabaseHelper();

      expect(
        () => dbHelper.insertWeightRecord(WeightRecord(
          petId: 'pet-que-no-existe',
          weight: 10.0,
          date: DateTime.now(),
        )),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('insertar una desparasitación con petId inexistente falla', () async {
      final dbHelper = DatabaseHelper();

      expect(
        () => dbHelper.insertDeworming(Deworming(
          petId: 'pet-que-no-existe',
          product: 'ProductoX',
          date: DateTime.now(),
        )),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('insertar una medicación con petId inexistente falla', () async {
      final dbHelper = DatabaseHelper();

      expect(
        () => dbHelper.insertMedication(Medication(
          petId: 'pet-que-no-existe',
          name: 'MedicamentoX',
          dosage: '1 pastilla',
          frequency: 'Diaria',
          notes: '',
          startDate: DateTime.now(),
        )),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
