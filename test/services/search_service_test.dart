// Pruebas de SearchService: mismo patrón de sqflite_common_ffi real que
// dashboard_providers_test.dart, porque lo que se prueba es la agregación
// real a través de DatabaseHelper.getXForPet para las 8 entidades con
// campo de texto libre -no solo la forma del servicio-.
import 'dart:io';

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
import 'package:pet_pal/models/search_result.dart';
import 'package:pet_pal/models/vaccination.dart';
import 'package:pet_pal/models/vital_sign_config.dart';
import 'package:pet_pal/models/vital_sign_record.dart';
import 'package:pet_pal/models/weight_record.dart';
import 'package:pet_pal/services/search_service.dart';

Future<Pet> _insertPet(
  DatabaseHelper dbHelper, {
  String name = 'Firulais',
  String breed = 'Mestizo',
  String species = 'Perro',
}) async {
  final pet = Pet(
    name: name,
    species: species,
    breed: breed,
    dob: DateTime(2020, 1, 1),
    color: 'Marrón',
  );
  await dbHelper.insertPet(pet);
  return pet;
}

void main() {
  late Directory tempDbDir;
  late DatabaseHelper dbHelper;
  late SearchService searchService;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDbDir = await Directory.systemTemp.createTemp('pet_pal_search_test_db_');
    // ignore: deprecated_member_use
    await databaseFactory.setDatabasesPath(tempDbDir.path);
  });

  tearDownAll(() async {
    try {
      if (await tempDbDir.exists()) {
        await tempDbDir.delete(recursive: true);
      }
    } catch (_) {
      // Se ignora: el SO limpia temporales eventualmente.
    }
  });

  setUp(() async {
    dbHelper = DatabaseHelper();
    await dbHelper.deleteAllData();
    searchService = SearchService(dbHelper);
  });

  group('normalizeForSearch', () {
    test('quita acentos y pasa a minúsculas', () {
      expect(normalizeForSearch('Vacunación'), 'vacunacion');
      expect(normalizeForSearch('RABIA'), 'rabia');
      expect(normalizeForSearch('áéíóúñÁÉÍÓÚÑ'), 'aeiounaeioun');
    });

    test('recorta espacios de los extremos', () {
      expect(normalizeForSearch('  Control  '), 'control');
    });
  });

  group('SearchService.search', () {
    test('query vacío devuelve lista vacía sin consultar la base de datos', () async {
      await _insertPet(dbHelper, name: 'Firulais');
      final results = await searchService.search('   ');
      expect(results, isEmpty);
    });

    test(
      'encuentra coincidencias en las 8 entidades con campo de texto libre, '
      'incluyendo campos que no son el "título" (notas, descripción, '
      'ubicación) para probar que se busca en todos los campos configurados',
      () async {
        final pet = await _insertPet(dbHelper, name: 'Rabito', breed: 'Golden Retriever');

        await dbHelper.insertFoodAllergy(FoodAllergy(
          petId: pet.id,
          food: 'Pollo con Rabito', // needle en el propio campo de texto
          dateRecorded: DateTime(2024, 1, 1),
        ));
        await dbHelper.insertAppointment(Appointment(
          petId: pet.id,
          dateTime: DateTime(2024, 2, 1),
          title: 'Control anual',
          description: 'Traer análisis de Rabito', // needle en description, no en title
        ));
        await dbHelper.insertDocument(Document(
          petId: pet.id,
          categoria: 'Receta',
          titulo: 'Análisis de sangre',
          fecha: DateTime(2024, 3, 1),
          filePath: '/tmp/doc.pdf',
          notas: 'Pedido por el Dr. para Rabito', // needle en notas, no en título
        ));
        await dbHelper.insertDeworming(Deworming(
          petId: pet.id,
          product: 'Drontal Rabito',
          date: DateTime(2024, 4, 1),
        ));
        await dbHelper.insertMedication(Medication(
          petId: pet.id,
          name: 'Amoxicilina',
          dosage: '250mg',
          frequency: 'Cada 12h',
          notes: 'Indicado para Rabito', // needle en notes, no en name
          startDate: DateTime(2024, 5, 1),
        ));
        await dbHelper.insertNote(Note(
          petId: pet.id,
          title: 'Chequeo',
          content: 'Todo en orden con Rabito', // needle en content, no en title
          date: DateTime(2024, 6, 1),
        ));
        await dbHelper.insertVaccination(Vaccination(
          petId: pet.id,
          vaccineName: 'Antirrábica de Rabito',
          date: DateTime(2024, 7, 1),
        ));

        final results = await searchService.search('rabito');

        // Pet + las 7 entidades insertadas arriba = 8 resultados.
        expect(results, hasLength(8));

        final typesFound = results.map((r) => r.type).toSet();
        expect(
          typesFound,
          {
            SearchEntityType.pet,
            SearchEntityType.foodAllergy,
            SearchEntityType.appointment,
            SearchEntityType.document,
            SearchEntityType.deworming,
            SearchEntityType.medication,
            SearchEntityType.note,
            SearchEntityType.vaccination,
          },
        );

        for (final result in results) {
          expect(result.pet.id, pet.id);
        }
      },
    );

    test('es insensible a mayúsculas y acentos de punta a punta (no solo en normalizeForSearch)', () async {
      final pet = await _insertPet(dbHelper);
      await dbHelper.insertVaccination(Vaccination(
        petId: pet.id,
        vaccineName: 'Antirrábica',
        date: DateTime(2024, 1, 1),
      ));

      final results = await searchService.search('ANTIRRABICA');

      expect(results, hasLength(1));
      expect(results.single.title, 'Antirrábica');
    });

    test('weight y vital_sign nunca aparecen en los resultados, aunque existan registros de la mascota', () async {
      final pet = await _insertPet(dbHelper, name: 'Numérico');

      // Coinciden con la búsqueda por mascota (petId compartido), pero no
      // tienen ningún campo de texto: no deberían poder aparecer nunca.
      await dbHelper.insertWeightRecord(WeightRecord(
        petId: pet.id,
        weight: 12.5,
        date: DateTime(2024, 1, 1),
      ));
      await dbHelper.insertVitalSignRecord(VitalSignRecord(
        petId: pet.id,
        type: VitalSignType.temperature,
        value: 38.5,
        date: DateTime(2024, 1, 1),
      ));

      final results = await searchService.search('numérico');

      // Solo debería matchear la propia mascota (por nombre); weight/vital
      // sign no tienen representación posible en SearchEntityType.
      expect(results, hasLength(1));
      expect(results.single.type, SearchEntityType.pet);
      // SearchEntityType, por diseño, no tiene valores para weight ni
      // vital_sign -esta lista es exhaustiva y sirve como guardia de
      // regresión si algún día se agrega uno por error sin excluirlo acá.
      expect(
        SearchEntityType.values,
        {
          SearchEntityType.pet,
          SearchEntityType.foodAllergy,
          SearchEntityType.appointment,
          SearchEntityType.document,
          SearchEntityType.deworming,
          SearchEntityType.medication,
          SearchEntityType.note,
          SearchEntityType.vaccination,
        },
      );
    });

    test('no devuelve coincidencias de otra mascota', () async {
      final petA = await _insertPet(dbHelper, name: 'Firulais');
      final petB = await _insertPet(dbHelper, name: 'Michi');

      await dbHelper.insertVaccination(Vaccination(
        petId: petA.id,
        vaccineName: 'Rabia',
        date: DateTime(2024, 1, 1),
      ));

      final results = await searchService.search('rabia');

      expect(results, hasLength(1));
      expect(results.single.pet.id, petA.id);
      expect(results.single.pet.id, isNot(petB.id));
    });
  });
}
