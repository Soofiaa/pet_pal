import 'package:flutter/material.dart';
import 'package:pet_pal/models/pet.dart';

/// Tipos de entidad que participan del buscador global (`SearchService`).
/// Deliberadamente no incluye peso ni signos vitales -son solo un número y
/// una fecha, sin campo de texto libre que un usuario pueda estar buscando-.
/// El orden de declaración es el orden en que se agrupan los resultados en
/// pantalla: mascota primero, y el resto siguiendo el mismo orden del grid
/// de accesos de pet_detail_screen.dart.
enum SearchEntityType {
  pet,
  foodAllergy,
  appointment,
  document,
  deworming,
  medication,
  note,
  vaccination,
}

class SearchEntityTypeConfig {
  const SearchEntityTypeConfig({required this.label, required this.icon});

  /// Encabezado de grupo en la pantalla de resultados (plural).
  final String label;
  final IconData icon;
}

/// Mismo ícono que ya usa cada pantalla/estado vacío para esta entidad
/// (ver empty_state.dart de cada pantalla), para que el buscador se sienta
/// consistente con el resto de la app en vez de inventar un set nuevo.
const Map<SearchEntityType, SearchEntityTypeConfig> searchEntityTypeConfigs = {
  SearchEntityType.pet: SearchEntityTypeConfig(label: 'Mascotas', icon: Icons.pets),
  SearchEntityType.foodAllergy:
      SearchEntityTypeConfig(label: 'Alergias alimentarias', icon: Icons.warning_amber_rounded),
  SearchEntityType.appointment: SearchEntityTypeConfig(label: 'Citas', icon: Icons.event_note),
  SearchEntityType.document: SearchEntityTypeConfig(label: 'Documentos', icon: Icons.folder_open_outlined),
  SearchEntityType.deworming: SearchEntityTypeConfig(label: 'Desparasitaciones', icon: Icons.healing),
  SearchEntityType.medication: SearchEntityTypeConfig(label: 'Medicaciones', icon: Icons.medication),
  SearchEntityType.note: SearchEntityTypeConfig(label: 'Notas', icon: Icons.note_alt_outlined),
  SearchEntityType.vaccination: SearchEntityTypeConfig(label: 'Vacunas', icon: Icons.vaccines),
};

/// Un resultado del buscador global: qué matcheó, de qué mascota, y el
/// registro original -para que la pantalla de resultados pueda navegar
/// directo a su AddEditXScreen sin volver a consultar la base de datos-.
class SearchResult {
  const SearchResult({
    required this.type,
    required this.pet,
    required this.title,
    this.subtitle,
    this.date,
    required this.record,
  });

  final SearchEntityType type;
  final Pet pet;

  /// Texto principal del resultado (ej. nombre de la vacuna, título de la nota).
  final String title;

  /// Texto secundario específico de la entidad (ej. categoría de un
  /// documento, dosis de una medicación). `null` cuando el título ya es
  /// toda la información relevante.
  final String? subtitle;

  /// `null` para mascotas, que no tienen una fecha asociada.
  final DateTime? date;

  /// Instancia original (Vaccination, Medication, Document, etc., o Pet
  /// cuando [type] es [SearchEntityType.pet]) -la pantalla de resultados la
  /// castea según [type] para navegar a la pantalla de edición correcta.
  final dynamic record;
}

/// Agrupa [results] por tipo de entidad -en el orden fijo de
/// [SearchEntityType], no por cantidad de coincidencias, para que la
/// posición de cada grupo sea predecible entre búsquedas- y ordena cada
/// grupo por fecha descendente (los registros sin fecha, como Pet, quedan
/// en el orden en que llegaron). Los grupos sin resultados no aparecen.
Map<SearchEntityType, List<SearchResult>> groupSearchResults(List<SearchResult> results) {
  final Map<SearchEntityType, List<SearchResult>> grouped = {
    for (final type in SearchEntityType.values) type: <SearchResult>[],
  };

  for (final result in results) {
    grouped[result.type]!.add(result);
  }

  for (final group in grouped.values) {
    group.sort((a, b) {
      if (a.date == null || b.date == null) return 0;
      return b.date!.compareTo(a.date!);
    });
  }

  grouped.removeWhere((_, group) => group.isEmpty);
  return grouped;
}
