import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/note.dart';
import 'package:pet_pal/models/vaccination.dart';
import 'package:pet_pal/models/appointment.dart';
import 'package:pet_pal/models/weight_record.dart';
import 'package:pet_pal/models/food_allergy.dart';
import 'package:pet_pal/models/deworming.dart';
import 'package:pet_pal/models/medication.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  static const String petsTable = 'pets';
  static const String notesTable = 'notes';
  static const String vaccinationsTable = 'vaccinations';
  static const String appointmentsTable = 'appointments';
  static const String weightRecordsTable = 'weight_records';
  static const String foodAllergiesTable = 'food_allergies';
  static const String dewormingsTable = 'dewormings';
  static const String medicationsTable = 'medications';

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'pet_pal_v2.db');
    return await openDatabase(
      path,
      version: 12,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Crear tabla de mascotas
    await db.execute('''
      CREATE TABLE $petsTable(
        id TEXT PRIMARY KEY,
        name TEXT,
        species TEXT,
        breed TEXT,
        dob TEXT,
        color TEXT,
        imageUrl TEXT
      )
    ''');
    debugPrint('Tabla de mascotas creada');

    // 2. Crear tabla de notas
    await db.execute('''
      CREATE TABLE $notesTable(
        id TEXT PRIMARY KEY,
        petId TEXT,
        title TEXT,
        date TEXT,
        content TEXT,
        photoPaths TEXT,
        FOREIGN KEY (petId) REFERENCES $petsTable (id) ON DELETE CASCADE
      )
    ''');
    debugPrint('Tabla de notas creada (con title)');

    // 3. Crear tabla de vacunaciones
    await db.execute('''
      CREATE TABLE $vaccinationsTable(
        id TEXT PRIMARY KEY,
        petId TEXT,
        vaccineName TEXT,
        date TEXT,
        nextDueDate TEXT,
        stickerPhotoPath TEXT,
        FOREIGN KEY (petId) REFERENCES $petsTable (id) ON DELETE CASCADE
      )
    ''');
    debugPrint('Tabla de vacunas creada');

    // 4. Crear tabla de citas
    await db.execute('''
      CREATE TABLE $appointmentsTable(
        id TEXT PRIMARY KEY,
        petId TEXT,
        dateTime TEXT,
        title TEXT,
        description TEXT,
        location TEXT,
        type TEXT,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (petId) REFERENCES $petsTable (id) ON DELETE CASCADE
      )
    ''');
    debugPrint('Tabla de citas creada (con isCompleted)');

    // 5. Crear tabla de registros de peso
    await db.execute('''
      CREATE TABLE $weightRecordsTable(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        petId TEXT,
        weight REAL,
        date TEXT,
        FOREIGN KEY (petId) REFERENCES $petsTable (id) ON DELETE CASCADE
      )
    ''');
    debugPrint('Tabla de registros de peso creada');

    // 6. Crear tabla de alergias
    await db.execute('''
      CREATE TABLE $foodAllergiesTable(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        petId TEXT,
        allergies TEXT NOT NULL,
        dateRecorded TEXT NOT NULL,
        FOREIGN KEY (petId) REFERENCES $petsTable (id) ON DELETE CASCADE
      )
    ''');
    debugPrint('Tabla de alergias creada (sin foodType)');

    // 7. Crear tabla de desparasitaciones
    await db.execute('''
      CREATE TABLE $dewormingsTable(
        id TEXT PRIMARY KEY,
        petId TEXT,
        product TEXT,
        date TEXT,
        nextDate TEXT,
        FOREIGN KEY (petId) REFERENCES $petsTable (id) ON DELETE CASCADE
      )
    ''');
    debugPrint('Tabla de desparasitaciones creada');

    // 8. Crear tabla de medicaciones
    await db.execute('''
      CREATE TABLE $medicationsTable(
        id TEXT PRIMARY KEY,
        petId TEXT,
        name TEXT,
        dosage TEXT,
        frequency TEXT,
        notes TEXT,
        startDate TEXT,
        endDate TEXT,
        FOREIGN KEY (petId) REFERENCES $petsTable (id) ON DELETE CASCADE
      )
    ''');
    debugPrint('Tabla de medicaciones creada');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // ... (El código de migración existente se mantiene igual)
    // El código de migración no necesita cambios si ya funciona.
  }

  // --- MÉTODOS AÑADIDOS PARA EL CALENDARIO ---
  Future<List<Map<String, dynamic>>> getAllEventsForPet(String petId) async {
    final db = await database;
    List<Map<String, dynamic>> allEvents = [];

    // Citas
    final appointmentMaps = await db.query(appointmentsTable, where: 'petId = ?', whereArgs: [petId]);
    final appointments = List.generate(appointmentMaps.length, (i) => Appointment.fromJson(appointmentMaps[i]));
    allEvents.addAll(Appointment.getEventsFromList(appointments));

    // Vacunaciones
    final vaccinationMaps = await db.query(vaccinationsTable, where: 'petId = ?', whereArgs: [petId]);
    final vaccinations = List.generate(vaccinationMaps.length, (i) => Vaccination.fromJson(vaccinationMaps[i]));
    allEvents.addAll(Vaccination.getEventsFromList(vaccinations));

    // Desparasitaciones
    final dewormingMaps = await db.query(dewormingsTable, where: 'petId = ?', whereArgs: [petId]);
    final dewormings = List.generate(dewormingMaps.length, (i) => Deworming.fromJson(dewormingMaps[i]));
    allEvents.addAll(Deworming.getEventsFromList(dewormings));

    // Medicaciones (NUEVO)
    final medicationMaps = await db.query(medicationsTable, where: 'petId = ?', whereArgs: [petId]);
    final medications = List.generate(medicationMaps.length, (i) => Medication.fromJson(medicationMaps[i]));
    allEvents.addAll(Medication.getEventsFromList(medications));

    // Notas
    final noteMaps = await db.query(notesTable, where: 'petId = ?', whereArgs: [petId]);
    final notes = List.generate(noteMaps.length, (i) => Note.fromJson(noteMaps[i]));
    allEvents.addAll(Note.getEventsFromList(notes));

    // Registros de Peso
    final weightMaps = await db.query(weightRecordsTable, where: 'petId = ?', whereArgs: [petId]);
    final weightRecords = List.generate(weightMaps.length, (i) => WeightRecord.fromJson(weightMaps[i]));
    allEvents.addAll(WeightRecord.getEventsFromList(weightRecords));

    return allEvents;
  }

  // --- MÉTODOS AÑADIDOS PARA EL RESPALDO DE DATOS ---

  // Método para borrar todos los datos de la base de datos
  Future<void> deleteAllData() async {
    final db = await database;
    await db.delete(petsTable);
    await db.delete(notesTable);
    await db.delete(weightRecordsTable);
    await db.delete(appointmentsTable);
    await db.delete(vaccinationsTable);
    await db.delete(foodAllergiesTable);
    await db.delete(dewormingsTable);
    await db.delete(medicationsTable);
    debugPrint('Todos los datos han sido eliminados de la base de datos.');
  }

  // --- Métodos para Mascotas (Pets) ---
  Future<void> insertPet(Pet pet) async {
    final db = await database;
    await db.insert(
      petsTable,
      pet.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('Mascota "${pet.name}" insertada/actualizada');
  }

  Future<List<Pet>> getPets() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(petsTable);
    return List.generate(maps.length, (i) {
      return Pet.fromJson(maps[i]);
    });
  }

  Future<void> updatePet(Pet pet) async {
    final db = await database;
    await db.update(
      petsTable,
      pet.toJson(),
      where: 'id = ?',
      whereArgs: [pet.id],
    );
    debugPrint('Mascota ${pet.id} actualizada');
  }

  Future<void> deletePet(String id) async {
    final db = await database;
    await db.delete(
      petsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint('Mascota $id eliminada. Registros asociados también eliminados.');
  }

  Future<Pet?> getPetById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      petsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Pet.fromJson(maps.first);
    }
    return null;
  }

  // --- Métodos para Notas (Notes) ---
  Future<void> insertNote(Note note) async {
    final db = await database;
    await db.insert(
      notesTable,
      note.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('Nota "${note.title}" para petId: ${note.petId} insertada/actualizada');
  }

  Future<List<Note>> getNotesForPet(String petId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      notesTable,
      where: 'petId = ?',
      whereArgs: [petId],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) {
      return Note.fromJson(maps[i]);
    });
  }

  Future<void> updateNote(Note note) async {
    final db = await database;
    await db.update(
      notesTable,
      note.toJson(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
    debugPrint('Nota ${note.id} actualizada');
  }

  Future<void> deleteNote(String id) async {
    final db = await database;
    await db.delete(
      notesTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint('Nota $id eliminada');
  }

  // --- Métodos para Vacunaciones (Vaccinations) ---
  Future<void> insertVaccination(Vaccination vaccination) async {
    final db = await database;
    await db.insert(
      vaccinationsTable,
      vaccination.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('Vacunación "${vaccination.vaccineName}" para petId: ${vaccination.petId} insertada/actualizada');
  }

  Future<List<Vaccination>> getVaccinationsForPet(String petId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      vaccinationsTable,
      where: 'petId = ?',
      whereArgs: [petId],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) {
      return Vaccination.fromJson(maps[i]);
    });
  }

  Future<void> updateVaccination(Vaccination vaccination) async {
    final db = await database;
    await db.update(
      vaccinationsTable,
      vaccination.toJson(),
      where: 'id = ?',
      whereArgs: [vaccination.id],
    );
    debugPrint('Vacunación ${vaccination.id} actualizada');
  }

  Future<void> deleteVaccination(String id) async {
    final db = await database;
    await db.delete(
      vaccinationsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint('Vacuna $id eliminada');
  }

  // --- Métodos para Citas (Appointments) ---
  Future<void> insertAppointment(Appointment appointment) async {
    final db = await database;
    await db.insert(
      appointmentsTable,
      appointment.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('Cita "${appointment.title}" para petId: ${appointment.petId} insertada/actualizada');
  }

  Future<List<Appointment>> getAppointmentsForPet(String petId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      appointmentsTable,
      where: 'petId = ?',
      whereArgs: [petId],
      orderBy: 'dateTime ASC',
    );
    return List.generate(maps.length, (i) {
      return Appointment.fromJson(maps[i]);
    });
  }

  Future<void> updateAppointment(Appointment appointment) async {
    final db = await database;
    await db.update(
      appointmentsTable,
      appointment.toJson(),
      where: 'id = ?',
      whereArgs: [appointment.id],
    );
    debugPrint('Cita ${appointment.id} actualizada');
  }

  Future<void> deleteAppointment(String id) async {
    final db = await database;
    await db.delete(
      appointmentsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint('Cita $id eliminada');
  }

  // --- Métodos para Registros de Peso (WeightRecords) ---

  Future<int> insertWeightRecord(WeightRecord record) async {
    final db = await database;
    final id = await db.insert(
      weightRecordsTable,
      record.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('Registro de peso para petId: ${record.petId} insertado/actualizado con id: $id');
    return id;
  }

  Future<List<WeightRecord>> getWeightRecordsForPet(String petId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      weightRecordsTable,
      where: 'petId = ?',
      whereArgs: [petId],
      orderBy: 'date ASC',
    );
    return List.generate(maps.length, (i) {
      return WeightRecord.fromJson(maps[i]);
    });
  }

  Future<void> updateWeightRecord(WeightRecord record) async {
    final db = await database;
    await db.update(
      weightRecordsTable,
      record.toJson(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
    debugPrint('Registro de peso ${record.id} actualizado');
  }

  Future<void> deleteWeightRecord(int id) async {
    final db = await database;
    await db.delete(
      weightRecordsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint('Registro de peso $id eliminado');
  }

  // --- Métodos para FoodAllergy (Alergias) ---
  Future<int> insertFoodAllergy(FoodAllergy foodAllergy) async {
    final db = await database;
    final id = await db.insert(
      foodAllergiesTable,
      foodAllergy.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  Future<List<FoodAllergy>> getFoodAllergiesForPet(String petId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      foodAllergiesTable,
      where: 'petId = ?',
      whereArgs: [petId],
      orderBy: 'dateRecorded DESC',
    );
    return List.generate(maps.length, (i) {
      return FoodAllergy.fromJson(maps[i]);
    });
  }

  Future<int> updateFoodAllergy(FoodAllergy foodAllergy) async {
    final db = await database;
    return await db.update(
      foodAllergiesTable,
      foodAllergy.toJson(),
      where: 'id = ?',
      whereArgs: [foodAllergy.id],
    );
  }

  Future<int> deleteFoodAllergy(int id) async {
    final db = await database;
    return await db.delete(
      foodAllergiesTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Métodos para Desparasitaciones ---
  Future<void> insertDeworming(Deworming deworming) async {
    final db = await database;
    await db.insert(
      dewormingsTable,
      deworming.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('Desparasitación "${deworming.product}" para petId: ${deworming.petId} insertada/actualizada');
  }

  Future<List<Deworming>> getDewormingsForPet(String petId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      dewormingsTable,
      where: 'petId = ?',
      whereArgs: [petId],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) {
      return Deworming.fromJson(maps[i]);
    });
  }

  Future<void> updateDeworming(Deworming deworming) async {
    final db = await database;
    await db.update(
      dewormingsTable,
      deworming.toJson(),
      where: 'id = ?',
      whereArgs: [deworming.id],
    );
    debugPrint('Desparasitación ${deworming.id} actualizada');
  }

  Future<void> deleteDeworming(String id) async {
    final db = await database;
    await db.delete(
      dewormingsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint('Desparasitación $id eliminada');
  }

  // --- Métodos para Medicaciones (Medications) ---
  Future<void> insertMedication(Medication medication) async {
    final db = await database;
    await db.insert(
      medicationsTable,
      medication.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('Medicación "${medication.name}" para petId: ${medication.petId} insertada/actualizada');
  }

  Future<List<Medication>> getMedicationsForPet(String petId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      medicationsTable,
      where: 'petId = ?',
      whereArgs: [petId],
      orderBy: 'startDate DESC',
    );
    return List.generate(maps.length, (i) {
      return Medication.fromJson(maps[i]);
    });
  }

  Future<void> updateMedication(Medication medication) async {
    final db = await database;
    await db.update(
      medicationsTable,
      medication.toJson(),
      where: 'id = ?',
      whereArgs: [medication.id],
    );
    debugPrint('Medicación ${medication.id} actualizada');
  }

  Future<void> deleteMedication(String id) async {
    final db = await database;
    await db.delete(
      medicationsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint('Medicación $id eliminada');
  }
}