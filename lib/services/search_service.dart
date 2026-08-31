import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/food_record.dart';
import 'package:pet_pal/models/search_result.dart';

/// Mapa mínimo de vocales/ñ acentuadas -> sin acento, para que buscar
/// "vacunacion" encuentre "Vacunación" y viceversa. No es una solución
/// general de folding Unicode, pero cubre el alfabeto español que es el
/// único que usan los datos de esta app.
const Map<String, String> _accentFold = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'ñ': 'n',
  'ç': 'c',
};

/// Normaliza texto para comparación de búsqueda: minúsculas + sin acentos.
/// Pública (no privada del archivo) para poder testearla directo.
String normalizeForSearch(String input) {
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_accentFold[char] ?? char);
  }
  return buffer.toString().trim();
}

/// Buscador global de texto libre entre todas las mascotas del usuario.
///
/// Cubre las 9 entidades con campo de texto libre (mascotas, alergias
/// alimentarias, historial de alimentos, citas, documentos,
/// desparasitaciones, medicaciones, notas, vacunas). Deliberadamente deja
/// afuera peso y signos vitales: son solo un número y una fecha, sin nada
/// que un usuario pueda "buscar" en el sentido de este feature.
///
/// Consulta [DatabaseHelper] directo para las 10 entidades por igual -no
/// mezcla con los repositories ya migrados (vacunación, medicación,
/// desparasitación, peso, signos vitales, mascota)-, siguiendo el mismo
/// patrón que ya usa `todayDashboardProvider` para combinar datos entre
/// mascotas: los repositories de hoy son pass-throughs sin lógica propia,
/// así que no hay beneficio en depender de dos formas distintas de pedir lo
/// mismo dentro de un único feature transversal.
///
/// El filtrado es en memoria (Dart `contains`, sin `LIKE` en SQL): con los
/// volúmenes típicos de esta app (decenas de registros por entidad) no hace
/// falta más, y permite normalizar acentos de forma uniforme sobre los
/// datos ya traídos -algo que SQLite `LIKE` no hace nativamente-.
class SearchService {
  SearchService(this._dbHelper);

  final DatabaseHelper _dbHelper;

  Future<List<SearchResult>> search(String query) async {
    final String normalizedQuery = normalizeForSearch(query);
    if (normalizedQuery.isEmpty) return [];

    final pets = await _dbHelper.getPets();
    final List<SearchResult> results = [];

    for (final pet in pets) {
      if (_matches(normalizedQuery, [pet.name, pet.breed, pet.species])) {
        results.add(SearchResult(
          type: SearchEntityType.pet,
          pet: pet,
          title: pet.name,
          subtitle: '${pet.species} · ${pet.breed}',
          record: pet,
        ));
      }

      final foodAllergies = await _dbHelper.getFoodAllergiesForPet(pet.id);
      for (final allergy in foodAllergies) {
        if (_matches(normalizedQuery, [allergy.food])) {
          results.add(SearchResult(
            type: SearchEntityType.foodAllergy,
            pet: pet,
            title: allergy.food,
            date: allergy.dateRecorded,
            record: allergy,
          ));
        }
      }

      final foodRecords = await _dbHelper.getFoodRecordsForPet(pet.id);
      for (final foodRecord in foodRecords) {
        if (_matches(normalizedQuery, [foodRecord.foodName, foodRecord.notes])) {
          results.add(SearchResult(
            type: SearchEntityType.foodRecord,
            pet: pet,
            title: foodRecord.foodName,
            subtitle: foodRecordStatusText(foodRecord),
            date: foodRecord.startDate,
            record: foodRecord,
          ));
        }
      }

      final appointments = await _dbHelper.getAppointmentsForPet(pet.id);
      for (final appointment in appointments) {
        if (_matches(normalizedQuery, [
          appointment.title,
          appointment.description,
          appointment.location,
          appointment.type,
        ])) {
          results.add(SearchResult(
            type: SearchEntityType.appointment,
            pet: pet,
            title: appointment.title,
            subtitle: appointment.location ?? appointment.description,
            date: appointment.dateTime,
            record: appointment,
          ));
        }
      }

      final documents = await _dbHelper.getDocumentsForPet(pet.id);
      for (final document in documents) {
        if (_matches(normalizedQuery, [document.titulo, document.categoria, document.notas])) {
          results.add(SearchResult(
            type: SearchEntityType.document,
            pet: pet,
            title: document.titulo,
            subtitle: document.categoria,
            date: document.fecha,
            record: document,
          ));
        }
      }

      final dewormings = await _dbHelper.getDewormingsForPet(pet.id);
      for (final deworming in dewormings) {
        if (_matches(normalizedQuery, [deworming.product])) {
          results.add(SearchResult(
            type: SearchEntityType.deworming,
            pet: pet,
            title: deworming.product,
            date: deworming.date,
            record: deworming,
          ));
        }
      }

      final medications = await _dbHelper.getMedicationsForPet(pet.id);
      for (final medication in medications) {
        if (_matches(normalizedQuery, [
          medication.name,
          medication.dosage,
          medication.frequency,
          medication.notes,
        ])) {
          results.add(SearchResult(
            type: SearchEntityType.medication,
            pet: pet,
            title: medication.name,
            subtitle: medication.dosage.isNotEmpty ? 'Dosis: ${medication.dosage}' : null,
            date: medication.startDate,
            record: medication,
          ));
        }
      }

      final notes = await _dbHelper.getNotesForPet(pet.id);
      for (final note in notes) {
        if (_matches(normalizedQuery, [note.title, note.content])) {
          results.add(SearchResult(
            type: SearchEntityType.note,
            pet: pet,
            title: note.title,
            subtitle: _truncate(note.content, 80),
            date: note.date,
            record: note,
          ));
        }
      }

      final vaccinations = await _dbHelper.getVaccinationsForPet(pet.id);
      for (final vaccination in vaccinations) {
        if (_matches(normalizedQuery, [vaccination.vaccineName])) {
          results.add(SearchResult(
            type: SearchEntityType.vaccination,
            pet: pet,
            title: vaccination.vaccineName,
            date: vaccination.date,
            record: vaccination,
          ));
        }
      }
    }

    return results;
  }

  bool _matches(String normalizedQuery, List<String?> fields) {
    return fields.any(
      (field) => field != null && field.isNotEmpty && normalizeForSearch(field).contains(normalizedQuery),
    );
  }

  String? _truncate(String text, int maxLength) {
    if (text.isEmpty) return null;
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
