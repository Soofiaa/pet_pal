import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/note.dart';
import 'package:pet_pal/models/vaccination.dart';
import 'package:pet_pal/models/appointment.dart';
import 'package:pet_pal/models/weight_record.dart';
import 'package:pet_pal/models/food_allergy.dart';
import 'package:pet_pal/models/food_record.dart';
import 'package:pet_pal/models/deworming.dart';
import 'package:pet_pal/models/medication.dart';
import 'package:pet_pal/models/document.dart';
import 'package:pet_pal/models/vital_sign_record.dart';
import 'package:pet_pal/models/deworming_product.dart';
import 'package:pet_pal/models/vaccination_product.dart';
import 'package:pet_pal/models/emergency_contact.dart';
import 'package:pet_pal/models/pet_food_config.dart';
import 'package:pet_pal/models/medication_intake.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  /// Resultado de la migración v17 (limpieza de filas huérfanas), por tabla.
  /// Solo se puebla si _onUpgrade realmente ejecutó esa migración en este
  /// lanzamiento del proceso — no se persiste a disco. Sirve como señal
  /// para que OrphanCleanupService sepa si corresponde también barrer
  /// archivos huérfanos en este mismo lanzamiento, reutilizando la propia
  /// versión de la base de datos como disparador único, sin agregar un
  /// mecanismo de "flag ya ejecutado" aparte.
  static Map<String, int>? lastOrphanRowCleanupCounts;

  static const String petsTable = 'pets';
  static const String notesTable = 'notes';
  static const String vaccinationsTable = 'vaccinations';
  static const String appointmentsTable = 'appointments';
  static const String weightRecordsTable = 'weight_records';
  static const String foodAllergiesTable = 'food_allergies';
  static const String dewormingsTable = 'dewormings';
  static const String medicationsTable = 'medications';
  static const String documentsTable = 'documents';
  static const String vitalSignsTable = 'vital_signs';

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  static const String dewormingProductsTable = 'deworming_products';
  static const String vaccinationProductsTable = 'vaccination_products';
  static const String emergencyContactsTable = 'emergency_contacts';
  static const String petFoodConfigsTable = 'pet_food_configs';
  static const String medicationIntakesTable = 'medication_intakes';
  static const String foodRecordsTable = 'food_records';

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'pet_pal_v2.db');
    return await openDatabase(
      path,
      version: 28,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Habilita la aplicación real de las restricciones de llave foránea
  /// (ON DELETE CASCADE, etc.) declaradas en el esquema. SQLite las ignora
  /// por conexión a menos que se pidan explícitamente con este PRAGMA.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
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
        imageUrl TEXT,
        microchipNumber TEXT,
        isNeutered INTEGER NOT NULL DEFAULT 0
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
        extraPhotoPath TEXT,
        reminderDaysAhead INTEGER NOT NULL DEFAULT 0,
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
        type TEXT,
        frequencyMonths INTEGER,
        reminderDaysAhead INTEGER NOT NULL DEFAULT 0,
        isRecurring INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (petId) REFERENCES $petsTable (id) ON DELETE CASCADE
      )
    ''');
    debugPrint('Tabla de desparasitaciones creada (v27 con isRecurring)');

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
        reminderTimes TEXT,
        FOREIGN KEY (petId) REFERENCES $petsTable (id) ON DELETE CASCADE
      )
    ''');
    debugPrint('Tabla de medicaciones creada');

    // 9. Crear tabla de documentos
    await db.execute('''
      CREATE TABLE $documentsTable(
        id TEXT PRIMARY KEY,
        petId TEXT,
        categoria TEXT,
        titulo TEXT,
        fecha TEXT,
        filePath TEXT,
        notas TEXT,
        FOREIGN KEY (petId) REFERENCES $petsTable (id) ON DELETE CASCADE
      )
    ''');
    debugPrint('Tabla de documentos creada');

    // 10. Crear tabla de signos vitales
    await db.execute('''
      CREATE TABLE $vitalSignsTable(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        petId TEXT,
        type TEXT,
        value REAL,
        date TEXT,
        FOREIGN KEY (petId) REFERENCES $petsTable (id) ON DELETE CASCADE
      )
    ''');
    debugPrint('Tabla de signos vitales creada');

    // 11. Crear tabla de productos desparasitantes
    await db.execute('''
      CREATE TABLE $dewormingProductsTable(
        id TEXT PRIMARY KEY,
        name TEXT,
        defaultFrequencyMonths INTEGER,
        defaultType TEXT
      )
    ''');
    debugPrint('Tabla de productos desparasitantes creada');

    // 12. Crear tabla de productos de vacunas
    await db.execute('''
      CREATE TABLE $vaccinationProductsTable(
        id TEXT PRIMARY KEY,
        name TEXT,
        defaultFrequencyMonths INTEGER
      )
    ''');
    debugPrint('Tabla de productos de vacunas creada');

    // 13. Crear tabla de contactos de emergencia
    await db.execute('''
      CREATE TABLE $emergencyContactsTable(
        id TEXT PRIMARY KEY,
        name TEXT,
        phone TEXT,
        category TEXT,
        notes TEXT
      )
    ''');
    debugPrint('Tabla de contactos de emergencia creada');

    // 14. Crear tabla de configuración de alimento
    await db.execute('''
      CREATE TABLE $petFoodConfigsTable(
        petId TEXT PRIMARY KEY,
        dailyGrams REAL,
        portions INTEGER,
        foodKcalPerKg REAL,
        FOREIGN KEY (petId) REFERENCES $petsTable (id) ON DELETE CASCADE
      )
    ''');
    debugPrint('Tabla de configuración de alimento creada');

    // 15. Crear tabla de tomas de medicación
    await db.execute('''
      CREATE TABLE $medicationIntakesTable(
        id TEXT PRIMARY KEY,
        petId TEXT,
        medicationId TEXT,
        intakeDateTime TEXT,
        medicationName TEXT,
        FOREIGN KEY (petId) REFERENCES $petsTable (id) ON DELETE CASCADE
      )
    ''');
    debugPrint('Tabla de tomas de medicación creada');

    // 16. Crear tabla de historial de alimentos
    await db.execute('''
      CREATE TABLE $foodRecordsTable(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        petId TEXT,
        foodName TEXT NOT NULL,
        startDate TEXT,
        endDate TEXT,
        notes TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (petId) REFERENCES $petsTable (id) ON DELETE CASCADE
      )
    ''');
    debugPrint('Tabla de historial de alimentos creada');
  }

  Future<List<String>> getVaccineNames() async {
    final db = await database;

    final result = await db.rawQuery('''
    SELECT DISTINCT vaccineName
    FROM $vaccinationsTable
    WHERE vaccineName IS NOT NULL AND TRIM(vaccineName) <> ''
    ORDER BY vaccineName COLLATE NOCASE
  ''');

    return result
        .map((row) => row['vaccineName'] as String)
        .toList();
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('DB upgrade: $oldVersion -> $newVersion');

    // Migración a v13: agregar microchipNumber a pets
    if (oldVersion < 13) {
      final exists = await _columnExists(db, petsTable, 'microchipNumber');
      if (!exists) {
        await db.execute('ALTER TABLE $petsTable ADD COLUMN microchipNumber TEXT');
        debugPrint('Columna microchipNumber agregada a $petsTable');
      } else {
        debugPrint('Columna microchipNumber ya existe en $petsTable');
      }
    }

    if (oldVersion < 14) {
      final exists = await _columnExists(db, vaccinationsTable, 'extraPhotoPath');
      if (!exists) {
        await db.execute('ALTER TABLE $vaccinationsTable ADD COLUMN extraPhotoPath TEXT');
        debugPrint('Columna extraPhotoPath agregada a $vaccinationsTable');
      } else {
        debugPrint('Columna extraPhotoPath ya existe en $vaccinationsTable');
      }
    }

    // Migración a v15: agregar reminderTimes a medications (horarios exactos
    // de toma). Las medicaciones existentes quedan con reminderTimes NULL
    // (equivalente a lista vacía en Medication.fromJson), por lo que
    // conservan su recordatorio único de las 9:00 AM hasta que se editen.
    if (oldVersion < 15) {
      final exists = await _columnExists(db, medicationsTable, 'reminderTimes');
      if (!exists) {
        await db.execute('ALTER TABLE $medicationsTable ADD COLUMN reminderTimes TEXT');
        debugPrint('Columna reminderTimes agregada a $medicationsTable');
      } else {
        debugPrint('Columna reminderTimes ya existe en $medicationsTable');
      }
    }

    // Migración a v16: nueva tabla documents (exámenes, cirugías,
    // radiografías, recetas), con el mismo ON DELETE CASCADE que el resto.
    if (oldVersion < 16) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $documentsTable(
          id TEXT PRIMARY KEY,
          petId TEXT,
          categoria TEXT,
          titulo TEXT,
          fecha TEXT,
          filePath TEXT,
          notas TEXT,
          FOREIGN KEY (petId) REFERENCES $petsTable (id) ON DELETE CASCADE
        )
      ''');
      debugPrint('Tabla de documentos creada (migración v16)');
    }

    // Migración a v17: limpieza única de filas huérfanas heredadas de antes
    // de activar PRAGMA foreign_keys = ON (ver _onConfigure). Hasta ese
    // cambio, eliminar una mascota nunca borraba en la práctica sus notas,
    // vacunas, citas, medicaciones, desparasitaciones, alergias ni
    // documentos: quedaban como filas huérfanas referenciando un petId que
    // ya no existe. Se ejecuta una sola vez porque _onUpgrade solo corre en
    // el salto de versión; no hace falta ninguna flag adicional.
    if (oldVersion < 17) {
      const List<String> tablesWithPetId = [
        notesTable,
        vaccinationsTable,
        appointmentsTable,
        weightRecordsTable,
        foodAllergiesTable,
        dewormingsTable,
        medicationsTable,
        documentsTable,
      ];

      final Map<String, int> deletedCounts = {};
      for (final table in tablesWithPetId) {
        final int deleted = await db.rawDelete(
          'DELETE FROM $table WHERE petId NOT IN (SELECT id FROM pets)',
        );
        deletedCounts[table] = deleted;
      }

      lastOrphanRowCleanupCounts = deletedCounts;
    }

    // Migración a v18: nueva tabla vital_signs (temperatura y, a futuro,
    // otros signos vitales), mismo ON DELETE CASCADE que el resto.
    if (oldVersion < 18) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $vitalSignsTable(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          petId TEXT,
          type TEXT,
          value REAL,
          date TEXT,
          FOREIGN KEY (petId) REFERENCES $petsTable (id) ON DELETE CASCADE
        )
      ''');
      debugPrint('Tabla de signos vitales creada (migración v18)');
    }

    // Migración a v19: agregar type y frequencyMonths a dewormings
    if (oldVersion < 19) {
      final hasType = await _columnExists(db, dewormingsTable, 'type');
      if (!hasType) {
        await db.execute('ALTER TABLE $dewormingsTable ADD COLUMN type TEXT');
      }
      final hasFrequency = await _columnExists(db, dewormingsTable, 'frequencyMonths');
      if (!hasFrequency) {
        await db.execute('ALTER TABLE $dewormingsTable ADD COLUMN frequencyMonths INTEGER');
      }
      debugPrint('Migración v19: Columnas type y frequencyMonths añadidas a $dewormingsTable');
    }

    // Migración a v20: nueva tabla de productos desparasitantes
    if (oldVersion < 20) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $dewormingProductsTable(
          id TEXT PRIMARY KEY,
          name TEXT,
          defaultFrequencyMonths INTEGER,
          defaultType TEXT
        )
      ''');
      debugPrint('Tabla de productos desparasitantes creada (migración v20)');
    }

    // Migración a v21: nueva tabla de productos de vacunas
    if (oldVersion < 21) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $vaccinationProductsTable(
          id TEXT PRIMARY KEY,
          name TEXT,
          defaultFrequencyMonths INTEGER
        )
      ''');
      debugPrint('Tabla de productos de vacunas creada (migración v21)');
    }

    // Migración a v22: agregar reminderDaysAhead a vacunas y desparasitaciones
    if (oldVersion < 22) {
      final hasVacReminder = await _columnExists(db, vaccinationsTable, 'reminderDaysAhead');
      if (!hasVacReminder) {
        await db.execute('ALTER TABLE $vaccinationsTable ADD COLUMN reminderDaysAhead INTEGER NOT NULL DEFAULT 0');
      }
      final hasDewReminder = await _columnExists(db, dewormingsTable, 'reminderDaysAhead');
      if (!hasDewReminder) {
        await db.execute('ALTER TABLE $dewormingsTable ADD COLUMN reminderDaysAhead INTEGER NOT NULL DEFAULT 0');
      }
      debugPrint('Migración v22: Columna reminderDaysAhead añadida a vacunas y desparasitaciones');
    }

    // Migración a v23: nueva tabla de contactos de emergencia
    if (oldVersion < 23) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $emergencyContactsTable(
          id TEXT PRIMARY KEY,
          name TEXT,
          phone TEXT,
          category TEXT,
          notes TEXT
        )
      ''');
      debugPrint('Tabla de contactos de emergencia creada (migración v23)');
    }

    // Migración a v24: nueva tabla de configuración de alimento
    if (oldVersion < 24) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $petFoodConfigsTable(
          petId TEXT PRIMARY KEY,
          dailyGrams REAL,
          portions INTEGER,
          foodKcalPerKg REAL,
          FOREIGN KEY (petId) REFERENCES $petsTable (id) ON DELETE CASCADE
        )
      ''');
      debugPrint('Tabla de configuración de alimento creada (migración v24)');
    }

    // Migración a v25: agregar isNeutered a pets
    if (oldVersion < 25) {
      final hasNeutered = await _columnExists(db, petsTable, 'isNeutered');
      if (!hasNeutered) {
        await db.execute('ALTER TABLE $petsTable ADD COLUMN isNeutered INTEGER NOT NULL DEFAULT 0');
      }
      debugPrint('Migración v25: Columna isNeutered añadida a $petsTable');
    }

    // Migración a v26: nueva tabla de tomas de medicación
    if (oldVersion < 26) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $medicationIntakesTable(
          id TEXT PRIMARY KEY,
          petId TEXT,
          medicationId TEXT,
          intakeDateTime TEXT,
          medicationName TEXT,
          FOREIGN KEY (petId) REFERENCES $petsTable (id) ON DELETE CASCADE
        )
      ''');
      debugPrint('Tabla de tomas de medicación creada (migración v26)');
    }

    // Migración a v27: agregar isRecurring a desparasitaciones (recordatorio
    // recurrente sin necesitar un registro nuevo cada ciclo).
    if (oldVersion < 27) {
      final hasRecurring = await _columnExists(db, dewormingsTable, 'isRecurring');
      if (!hasRecurring) {
        await db.execute('ALTER TABLE $dewormingsTable ADD COLUMN isRecurring INTEGER NOT NULL DEFAULT 0');
      }
      debugPrint('Migración v27: Columna isRecurring añadida a $dewormingsTable');
    }

    // Migración a v28: nueva tabla food_records (historial de qué alimento
    // se le fue dando a la mascota). startDate y endDate son ambas
    // opcionales: startDate null = no se recuerda cuándo empezó, endDate
    // null = lo sigue comiendo.
    if (oldVersion < 28) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $foodRecordsTable(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          petId TEXT,
          foodName TEXT NOT NULL,
          startDate TEXT,
          endDate TEXT,
          notes TEXT NOT NULL DEFAULT '',
          FOREIGN KEY (petId) REFERENCES $petsTable (id) ON DELETE CASCADE
        )
      ''');
      debugPrint('Tabla de historial de alimentos creada (migración v28)');
    }

    // Si tienes migraciones antiguas que antes estaban en onUpgrade,
    // van aquí también, respetando el patrón: if (oldVersion < X) { ... }
  }

  /// Verifica si una columna existe (evita que ALTER TABLE falle).
  Future<bool> _columnExists(Database db, String table, String column) async {
    final result = await db.rawQuery('PRAGMA table_info($table)');
    return result.any((row) => row['name'] == column);
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

    // Historial de alimentos
    final foodRecordMaps = await db.query(foodRecordsTable, where: 'petId = ?', whereArgs: [petId]);
    final foodRecords = List.generate(foodRecordMaps.length, (i) => FoodRecord.fromJson(foodRecordMaps[i]));
    allEvents.addAll(FoodRecord.getEventsFromList(foodRecords));

    // Notas
    final noteMaps = await db.query(notesTable, where: 'petId = ?', whereArgs: [petId]);
    final notes = List.generate(noteMaps.length, (i) => Note.fromJson(noteMaps[i]));
    allEvents.addAll(Note.getEventsFromList(notes));

    // Registros de Peso
    final weightMaps = await db.query(weightRecordsTable, where: 'petId = ?', whereArgs: [petId]);
    final weightRecords = List.generate(weightMaps.length, (i) => WeightRecord.fromJson(weightMaps[i]));
    allEvents.addAll(WeightRecord.getEventsFromList(weightRecords));

    // Documentos
    final documentMaps = await db.query(documentsTable, where: 'petId = ?', whereArgs: [petId]);
    final documents = List.generate(documentMaps.length, (i) => Document.fromJson(documentMaps[i]));
    allEvents.addAll(Document.getEventsFromList(documents));

    // Alergias Alimentarias
    final foodAllergyMaps = await db.query(foodAllergiesTable, where: 'petId = ?', whereArgs: [petId]);
    final foodAllergies = List.generate(foodAllergyMaps.length, (i) => FoodAllergy.fromJson(foodAllergyMaps[i]));
    allEvents.addAll(FoodAllergy.getEventsFromList(foodAllergies));

    // Signos Vitales
    final vitalSignMaps = await db.query(vitalSignsTable, where: 'petId = ?', whereArgs: [petId]);
    final vitalSigns = List.generate(vitalSignMaps.length, (i) => VitalSignRecord.fromJson(vitalSignMaps[i]));
    allEvents.addAll(VitalSignRecord.getEventsFromList(vitalSigns));

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
    await db.delete(documentsTable);
    await db.delete(vitalSignsTable);
    await db.delete(dewormingProductsTable);
    await db.delete(vaccinationProductsTable);
    await db.delete(emergencyContactsTable);
    await db.delete(petFoodConfigsTable);
    await db.delete(medicationIntakesTable);
    await db.delete(foodRecordsTable);
    debugPrint('Todos los datos han sido eliminados de la base de datos.');
  }

  // --- Métodos para Tomas de Medicación (MedicationIntake) ---
  Future<void> insertMedicationIntake(MedicationIntake intake) async {
    final db = await database;
    await db.insert(
      medicationIntakesTable,
      intake.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MedicationIntake>> getIntakesForMedication(String medicationId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      medicationIntakesTable,
      where: 'medicationId = ?',
      whereArgs: [medicationId],
      orderBy: 'intakeDateTime DESC',
    );
    return List.generate(maps.length, (i) => MedicationIntake.fromJson(maps[i]));
  }

  Future<void> deleteIntake(String id) async {
    final db = await database;
    await db.delete(medicationIntakesTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<MedicationIntake>> getAllIntakesForPet(String petId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      medicationIntakesTable,
      where: 'petId = ?',
      whereArgs: [petId],
      orderBy: 'intakeDateTime DESC',
    );
    return List.generate(maps.length, (i) => MedicationIntake.fromJson(maps[i]));
  }

  // --- Métodos para Configuración de Alimento (PetFoodConfig) ---
  Future<void> insertOrUpdateFoodConfig(PetFoodConfig config) async {
    final db = await database;
    await db.insert(
      petFoodConfigsTable,
      config.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<PetFoodConfig?> getFoodConfigForPet(String petId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      petFoodConfigsTable,
      where: 'petId = ?',
      whereArgs: [petId],
    );
    if (maps.isNotEmpty) {
      return PetFoodConfig.fromJson(maps.first);
    }
    return null;
  }

  // --- Métodos para Contactos de Emergencia (EmergencyContacts) ---
  Future<void> insertEmergencyContact(EmergencyContact contact) async {
    final db = await database;
    await db.insert(
      emergencyContactsTable,
      contact.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<EmergencyContact>> getEmergencyContacts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(emergencyContactsTable, orderBy: 'name ASC');
    return List.generate(maps.length, (i) {
      return EmergencyContact.fromJson(maps[i]);
    });
  }

  Future<void> deleteEmergencyContact(String id) async {
    final db = await database;
    await db.delete(
      emergencyContactsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateEmergencyContact(EmergencyContact contact) async {
    final db = await database;
    await db.update(
      emergencyContactsTable,
      contact.toJson(),
      where: 'id = ?',
      whereArgs: [contact.id],
    );
  }

  // --- Métodos para Productos de Vacunas (VaccinationProducts) ---
  Future<void> insertVaccinationProduct(VaccinationProduct product) async {
    final db = await database;
    await db.insert(
      vaccinationProductsTable,
      product.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // Sincronizar registros existentes
    await db.update(
      vaccinationsTable,
      {
        // En vacunas solo sincronizamos el nombre si fuera necesario, 
        // pero aquí no hay campo frequency directo en la tabla de vacunas, 
        // se usa para calcular nextDueDate al momento de insertar.
      },
      where: 'vaccineName = ?',
      whereArgs: [product.name],
    );
  }

  Future<List<VaccinationProduct>> getVaccinationProducts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(vaccinationProductsTable, orderBy: 'name ASC');
    return List.generate(maps.length, (i) {
      return VaccinationProduct.fromJson(maps[i]);
    });
  }

  Future<void> deleteVaccinationProduct(String id) async {
    final db = await database;
    await db.delete(
      vaccinationProductsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateVaccinationProduct(VaccinationProduct product) async {
    final db = await database;
    await db.update(
      vaccinationProductsTable,
      product.toJson(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  // --- Métodos para Productos Desparasitantes (DewormingProducts) ---
  Future<void> insertDewormingProduct(DewormingProduct product) async {
    final db = await database;
    await db.insert(
      dewormingProductsTable,
      product.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // ✅ Sincronizar registros existentes: si hay desparasitaciones con este nombre,
    // actualizamos su tipo y frecuencia para que coincidan con el catálogo.
    await db.update(
      dewormingsTable,
      {
        'type': product.defaultType,
        'frequencyMonths': product.defaultFrequencyMonths,
      },
      where: 'product = ?',
      whereArgs: [product.name],
    );
  }

  Future<List<DewormingProduct>> getDewormingProducts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(dewormingProductsTable, orderBy: 'name ASC');
    return List.generate(maps.length, (i) {
      return DewormingProduct.fromJson(maps[i]);
    });
  }

  Future<void> deleteDewormingProduct(String id) async {
    final db = await database;
    await db.delete(
      dewormingProductsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateDewormingProduct(DewormingProduct product) async {
    final db = await database;
    await db.update(
      dewormingProductsTable,
      product.toJson(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
    // ✅ Sincronizar también al editar el producto del catálogo
    await db.update(
      dewormingsTable,
      {
        'type': product.defaultType,
        'frequencyMonths': product.defaultFrequencyMonths,
      },
      where: 'product = ?',
      whereArgs: [product.name],
    );
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

  Future<List<String>> getDewormingProductNames() async {
    final db = await database;

    final result = await db.rawQuery('''
    SELECT DISTINCT product
    FROM $dewormingsTable
    WHERE product IS NOT NULL AND TRIM(product) <> ''
    ORDER BY product COLLATE NOCASE
  ''');

    return result
        .map((row) => row['product'] as String)
        .toList();
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

  // --- Métodos para Signos Vitales (VitalSignRecords) ---

  Future<int> insertVitalSignRecord(VitalSignRecord record) async {
    final db = await database;
    final id = await db.insert(
      vitalSignsTable,
      record.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('Signo vital para petId: ${record.petId} insertado/actualizado con id: $id');
    return id;
  }

  Future<List<VitalSignRecord>> getVitalSignRecordsForPet(String petId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      vitalSignsTable,
      where: 'petId = ?',
      whereArgs: [petId],
      orderBy: 'date ASC',
    );
    return List.generate(maps.length, (i) {
      return VitalSignRecord.fromJson(maps[i]);
    });
  }

  Future<void> updateVitalSignRecord(VitalSignRecord record) async {
    final db = await database;
    await db.update(
      vitalSignsTable,
      record.toJson(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
    debugPrint('Signo vital ${record.id} actualizado');
  }

  Future<void> deleteVitalSignRecord(int id) async {
    final db = await database;
    await db.delete(
      vitalSignsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint('Signo vital $id eliminado');
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

  // --- Métodos para FoodRecord (Historial de Alimentos) ---
  Future<int> insertFoodRecord(FoodRecord foodRecord) async {
    final db = await database;
    final id = await db.insert(
      foodRecordsTable,
      foodRecord.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  Future<List<FoodRecord>> getFoodRecordsForPet(String petId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      foodRecordsTable,
      where: 'petId = ?',
      whereArgs: [petId],
    );
    return List.generate(maps.length, (i) {
      return FoodRecord.fromJson(maps[i]);
    });
  }

  Future<int> updateFoodRecord(FoodRecord foodRecord) async {
    final db = await database;
    return await db.update(
      foodRecordsTable,
      foodRecord.toJson(),
      where: 'id = ?',
      whereArgs: [foodRecord.id],
    );
  }

  Future<int> deleteFoodRecord(int id) async {
    final db = await database;
    return await db.delete(
      foodRecordsTable,
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

  // --- Métodos para Documentos (Documents) ---
  Future<void> insertDocument(Document document) async {
    final db = await database;
    await db.insert(
      documentsTable,
      document.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('Documento "${document.titulo}" para petId: ${document.petId} insertado/actualizado');
  }

  Future<List<Document>> getDocumentsForPet(String petId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      documentsTable,
      where: 'petId = ?',
      whereArgs: [petId],
      orderBy: 'fecha DESC',
    );
    return List.generate(maps.length, (i) {
      return Document.fromJson(maps[i]);
    });
  }

  Future<void> updateDocument(Document document) async {
    final db = await database;
    await db.update(
      documentsTable,
      document.toJson(),
      where: 'id = ?',
      whereArgs: [document.id],
    );
    debugPrint('Documento ${document.id} actualizado');
  }

  Future<void> deleteDocument(String id) async {
    final db = await database;
    await db.delete(
      documentsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint('Documento $id eliminado');
  }
}